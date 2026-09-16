import 'dart:math';

import 'congressional_delivery_service.dart';
import 'congressional_district_service.dart';

enum ContactCongressVerificationMode { preview, live }

class ContactCongressVerificationException implements Exception {
  const ContactCongressVerificationException(this.message);

  final String message;

  @override
  String toString() => 'ContactCongressVerificationException: $message';
}

class CongressionalAddressProof {
  const CongressionalAddressProof({
    required this.token,
    required this.matchedAddress,
    required this.stateAbbreviation,
    required this.districtCode,
    required this.benchmark,
    required this.vintage,
    required this.expiresAt,
    required this.mode,
  });

  final String token;
  final String matchedAddress;
  final String stateAbbreviation;
  final String districtCode;
  final String benchmark;
  final String vintage;
  final DateTime expiresAt;
  final ContactCongressVerificationMode mode;

  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());

  factory CongressionalAddressProof.preview({required String address}) {
    return CongressionalAddressProof(
      token: 'preview-address-proof',
      matchedAddress: address,
      stateAbbreviation: '',
      districtCode: '',
      benchmark: 'Public_AR_Current',
      vintage: 'Current_Current',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 30)),
      mode: ContactCongressVerificationMode.preview,
    );
  }
}

class EmailVerificationChallenge {
  const EmailVerificationChallenge({
    required this.id,
    required this.maskedEmail,
    required this.expiresAt,
    required this.mode,
    this.previewCode,
  });

  final String id;
  final String maskedEmail;
  final DateTime expiresAt;
  final ContactCongressVerificationMode mode;

  /// Present only in the development verifier. A live backend must never
  /// return the verification code to the client.
  final String? previewCode;
}

class EmailVerificationProof {
  const EmailVerificationProof({
    required this.token,
    required this.normalizedEmail,
    required this.expiresAt,
    required this.mode,
  });

  final String token;
  final String normalizedEmail;
  final DateTime expiresAt;
  final ContactCongressVerificationMode mode;

  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());

  bool matches(String email) =>
      !isExpired && normalizedEmail == normalizeCongressionalEmail(email);
}

class HumanChallengeProof {
  const HumanChallengeProof({
    required this.token,
    required this.action,
    required this.expiresAt,
    required this.mode,
  });

  final String token;
  final String action;
  final DateTime expiresAt;
  final ContactCongressVerificationMode mode;

  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());
}

class CongressionalSendAuthorizationRequest {
  const CongressionalSendAuthorizationRequest({
    required this.addressProof,
    required this.emailProof,
    required this.humanProof,
    required this.email,
    required this.address,
    required this.recipients,
    required this.topic,
    required this.subject,
    required this.message,
    required this.attestationVersion,
    required this.attestedAt,
  });

  final CongressionalAddressProof addressProof;
  final EmailVerificationProof emailProof;
  final HumanChallengeProof humanProof;
  final String email;
  final String address;
  final List<CongressionalDeliveryRecipient> recipients;
  final String topic;
  final String subject;
  final String message;
  final String attestationVersion;
  final DateTime attestedAt;
}

class CongressionalSendAuthorization {
  const CongressionalSendAuthorization({
    required this.token,
    required this.idempotencyKey,
    required this.issuedAt,
    required this.expiresAt,
    required this.mode,
  });

  final String token;
  final String idempotencyKey;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final ContactCongressVerificationMode mode;

  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());
}

abstract class ContactCongressVerificationGateway {
  ContactCongressVerificationMode get mode;

  Future<CongressionalAddressProof> issueAddressProof({
    required CongressionalDistrictAddress address,
    required CongressionalDistrictMatch match,
  });

  Future<EmailVerificationChallenge> startEmailVerification(String email);

  Future<EmailVerificationProof> confirmEmailVerification({
    required EmailVerificationChallenge challenge,
    required String code,
  });

  Future<HumanChallengeProof> verifyHumanChallenge({
    required String action,
    String? clientToken,
  });

  Future<CongressionalSendAuthorization> authorizeSend(
    CongressionalSendAuthorizationRequest request,
  );
}

/// Development-only verifier that exercises the complete trust flow without
/// sending email, contacting a bot provider, or issuing a production token.
///
/// Production builds must replace this with an application-owned HTTPS
/// gateway. The UI labels every proof produced here as a preview.
class PreviewContactCongressVerificationGateway
    implements ContactCongressVerificationGateway {
  PreviewContactCongressVerificationGateway({
    this.verificationCode = '246810',
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final String verificationCode;
  final DateTime Function() _clock;
  final Map<String, _PreviewEmailChallengeRecord> _emailChallenges = {};
  final Random _random = Random.secure();

  @override
  ContactCongressVerificationMode get mode =>
      ContactCongressVerificationMode.preview;

  @override
  Future<CongressionalAddressProof> issueAddressProof({
    required CongressionalDistrictAddress address,
    required CongressionalDistrictMatch match,
  }) async {
    if (match.matchedAddress.trim().isEmpty ||
        match.stateAbbreviation != address.state.trim().toUpperCase()) {
      throw const ContactCongressVerificationException(
        'The Census match did not agree with the entered state.',
      );
    }
    return CongressionalAddressProof(
      token: _token('address'),
      matchedAddress: match.matchedAddress,
      stateAbbreviation: match.stateAbbreviation,
      districtCode: match.districtCode,
      benchmark: match.benchmark,
      vintage: match.vintage,
      expiresAt: _clock().add(const Duration(minutes: 30)),
      mode: mode,
    );
  }

  @override
  Future<EmailVerificationChallenge> startEmailVerification(
    String email,
  ) async {
    final normalizedEmail = normalizeCongressionalEmail(email);
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalizedEmail)) {
      throw const ContactCongressVerificationException(
        'Enter a valid email address before requesting a code.',
      );
    }
    final id = _token('email-challenge');
    final expiresAt = _clock().add(const Duration(minutes: 10));
    _emailChallenges[id] = _PreviewEmailChallengeRecord(
      normalizedEmail: normalizedEmail,
      expiresAt: expiresAt,
    );
    return EmailVerificationChallenge(
      id: id,
      maskedEmail: maskCongressionalEmail(normalizedEmail),
      expiresAt: expiresAt,
      mode: mode,
      previewCode: verificationCode,
    );
  }

  @override
  Future<EmailVerificationProof> confirmEmailVerification({
    required EmailVerificationChallenge challenge,
    required String code,
  }) async {
    final record = _emailChallenges[challenge.id];
    if (record == null) {
      throw const ContactCongressVerificationException(
        'This verification request is no longer available.',
      );
    }
    if (!record.expiresAt.isAfter(_clock())) {
      _emailChallenges.remove(challenge.id);
      throw const ContactCongressVerificationException(
        'That code expired. Request a new one.',
      );
    }
    record.attempts++;
    if (record.attempts > 5) {
      _emailChallenges.remove(challenge.id);
      throw const ContactCongressVerificationException(
        'Too many attempts. Request a new code.',
      );
    }
    if (code.trim() != verificationCode) {
      throw const ContactCongressVerificationException(
        'That code does not match. Try again.',
      );
    }
    _emailChallenges.remove(challenge.id);
    return EmailVerificationProof(
      token: _token('email-proof'),
      normalizedEmail: record.normalizedEmail,
      expiresAt: _clock().add(const Duration(minutes: 30)),
      mode: mode,
    );
  }

  @override
  Future<HumanChallengeProof> verifyHumanChallenge({
    required String action,
    String? clientToken,
  }) async {
    if (action != 'contact_congress_send') {
      throw const ContactCongressVerificationException(
        'The human-check action was invalid.',
      );
    }
    return HumanChallengeProof(
      token: _token('human-proof'),
      action: action,
      expiresAt: _clock().add(const Duration(minutes: 5)),
      mode: mode,
    );
  }

  @override
  Future<CongressionalSendAuthorization> authorizeSend(
    CongressionalSendAuthorizationRequest request,
  ) async {
    if (request.addressProof.isExpired ||
        request.emailProof.isExpired ||
        request.humanProof.isExpired) {
      throw const ContactCongressVerificationException(
        'A verification expired. Please verify again.',
      );
    }
    if (!request.emailProof.matches(request.email)) {
      throw const ContactCongressVerificationException(
        'The confirmed email no longer matches this message.',
      );
    }
    if (request.addressProof.matchedAddress != request.address.trim()) {
      throw const ContactCongressVerificationException(
        'The matched address changed. Match the district again.',
      );
    }
    if (request.humanProof.action != 'contact_congress_send' ||
        request.recipients.isEmpty ||
        request.subject.trim().isEmpty ||
        request.message.trim().isEmpty ||
        request.attestationVersion != 'contact-congress-v1') {
      throw const ContactCongressVerificationException(
        'The send request was incomplete.',
      );
    }
    final issuedAt = _clock();
    return CongressionalSendAuthorization(
      token: _token('send-authorization'),
      idempotencyKey: _token('delivery'),
      issuedAt: issuedAt,
      expiresAt: issuedAt.add(const Duration(minutes: 5)),
      mode: mode,
    );
  }

  String _token(String prefix) {
    final bytes = List<int>.generate(18, (_) => _random.nextInt(256));
    final value = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
    return '$prefix-${value.join()}';
  }
}

class _PreviewEmailChallengeRecord {
  _PreviewEmailChallengeRecord({
    required this.normalizedEmail,
    required this.expiresAt,
  });

  final String normalizedEmail;
  final DateTime expiresAt;
  int attempts = 0;
}

String normalizeCongressionalEmail(String email) => email.trim().toLowerCase();

String maskCongressionalEmail(String email) {
  final normalized = normalizeCongressionalEmail(email);
  final parts = normalized.split('@');
  if (parts.length != 2 || parts.first.isEmpty) return normalized;
  final local = parts.first;
  final visible = local.length == 1 ? local : local.substring(0, 1);
  final bullets = List.filled(min(5, max(2, local.length - 1)), '•').join();
  return '$visible$bullets@${parts.last}';
}
