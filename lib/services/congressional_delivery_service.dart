/// Delivery contracts used by the Flutter client.
///
/// The client must only call an application-owned backend implementing
/// [CongressionalDeliveryGateway]. House CWC and Senate SCWC credentials,
/// endpoints, XML/SOAP payloads, and signing material must never be added to
/// this Flutter package.
enum CongressionalChamber { house, senate }

enum CongressionalDeliveryStatus {
  /// The app backend is not configured or the chamber has not been approved.
  unavailable,

  /// The backend needs another app or user action before it can route this.
  needsUserAction,

  /// The chamber gateway accepted the message for routing. This is not proof
  /// that an office or staff member read it.
  acceptedForRouting,

  /// Reserved until a chamber contract confirms an authoritative meaning.
  delivered,

  /// A non-retryable rejection returned by the backend or chamber.
  rejected,

  /// A temporary failure; the app may retry or notify the constituent.
  failed,
}

class CongressionalDeliveryRecipient {
  const CongressionalDeliveryRecipient({
    required this.name,
    required this.chamber,
    required this.officialUrl,
    this.bioguideId,
  });

  final String name;
  final CongressionalChamber chamber;
  final String officialUrl;
  final String? bioguideId;
}

class CongressionalConstituent {
  const CongressionalConstituent({
    required this.fullName,
    required this.email,
    required this.address,
    required this.state,
  });

  final String fullName;
  final String email;
  final String address;
  final String state;
}

class CongressionalDeliveryRequest {
  const CongressionalDeliveryRequest({
    required this.idempotencyKey,
    required this.constituent,
    required this.topic,
    required this.subject,
    required this.message,
    required this.recipients,
    required this.authorizedAt,
  });

  final String idempotencyKey;
  final CongressionalConstituent constituent;
  final String topic;
  final String subject;
  final String message;
  final List<CongressionalDeliveryRecipient> recipients;
  final DateTime authorizedAt;
}

class CongressionalOfficeDeliveryResult {
  const CongressionalOfficeDeliveryResult({
    required this.recipient,
    required this.status,
    required this.message,
    this.receiptId,
  });

  final CongressionalDeliveryRecipient recipient;
  final CongressionalDeliveryStatus status;
  final String message;
  final String? receiptId;

  bool get requiresFollowUp =>
      status != CongressionalDeliveryStatus.acceptedForRouting &&
      status != CongressionalDeliveryStatus.delivered;
}

class CongressionalDeliveryResult {
  const CongressionalDeliveryResult({
    required this.idempotencyKey,
    required this.offices,
    this.wasDuplicate = false,
  });

  final String idempotencyKey;
  final List<CongressionalOfficeDeliveryResult> offices;
  final bool wasDuplicate;

  CongressionalDeliveryResult asDuplicate() => CongressionalDeliveryResult(
    idempotencyKey: idempotencyKey,
    offices: offices,
    wasDuplicate: true,
  );
}

abstract class CongressionalDeliveryGateway {
  /// True only when an application-owned backend has been configured and is
  /// allowed to attempt approval-gated delivery.
  bool get canAttemptDirectDelivery;

  Future<CongressionalDeliveryResult> submit(
    CongressionalDeliveryRequest request,
  );
}

/// Safe production default until the backend and chamber approvals exist.
class PlaceholderCongressionalDeliveryGateway
    implements CongressionalDeliveryGateway {
  const PlaceholderCongressionalDeliveryGateway();

  @override
  bool get canAttemptDirectDelivery => false;

  @override
  Future<CongressionalDeliveryResult> submit(
    CongressionalDeliveryRequest request,
  ) async {
    return CongressionalDeliveryResult(
      idempotencyKey: request.idempotencyKey,
      offices: [
        for (final recipient in request.recipients)
          CongressionalOfficeDeliveryResult(
            recipient: recipient,
            status: CongressionalDeliveryStatus.unavailable,
            message:
                '${recipient.chamber == CongressionalChamber.house ? 'House CWC' : 'Senate SCWC'} API placeholder: approval and credentials are not configured. Nothing was transmitted.',
          ),
      ],
    );
  }
}

/// Prevents a double tap or retry from creating a second submission during the
/// current app session. Production deduplication must also be enforced by the
/// backend and persisted across processes.
class IdempotentCongressionalDeliveryService {
  IdempotentCongressionalDeliveryService(this._gateway);

  final CongressionalDeliveryGateway _gateway;
  final Map<String, Future<CongressionalDeliveryResult>> _requests = {};

  bool get canAttemptDirectDelivery => _gateway.canAttemptDirectDelivery;

  Future<CongressionalDeliveryResult> submit(
    CongressionalDeliveryRequest request,
  ) {
    final existing = _requests[request.idempotencyKey];
    if (existing != null) {
      return existing.then((result) => result.asDuplicate());
    }
    final future = _gateway.submit(request);
    _requests[request.idempotencyKey] = future;
    return future;
  }
}
