import 'package:flutter_test/flutter_test.dart';
import 'package:usa_map_app/services/contact_congress_verification_service.dart';
import 'package:usa_map_app/services/congressional_delivery_service.dart';
import 'package:usa_map_app/services/congressional_district_service.dart';

void main() {
  const address = CongressionalDistrictAddress(
    street: '123 Main St',
    city: 'Austin',
    state: 'TX',
    zip: '78701',
  );
  const match = CongressionalDistrictMatch(
    matchedAddress: '123 MAIN ST, AUSTIN, TX, 78701',
    stateAbbreviation: 'TX',
    stateFips: '48',
    districtNumber: 35,
    districtCode: '35',
    congressionalSession: '119',
    benchmark: 'Public_AR_Current',
    vintage: 'Current_Current',
  );
  const recipient = CongressionalDeliveryRecipient(
    name: 'House Member',
    chamber: CongressionalChamber.house,
    officialUrl: 'https://member.house.gov/contact',
    bioguideId: 'H000001',
  );

  test('issues a preview address proof only for the matching state', () async {
    final gateway = PreviewContactCongressVerificationGateway();

    final proof = await gateway.issueAddressProof(
      address: address,
      match: match,
    );

    expect(proof.matchedAddress, match.matchedAddress);
    expect(proof.stateAbbreviation, 'TX');
    expect(proof.districtCode, '35');
    expect(proof.benchmark, 'Public_AR_Current');
    expect(proof.vintage, 'Current_Current');
    expect(proof.mode, ContactCongressVerificationMode.preview);
  });

  test(
    'confirms the preview email code once and removes the challenge',
    () async {
      final gateway = PreviewContactCongressVerificationGateway();
      final challenge = await gateway.startEmailVerification(
        ' Taylor@Example.com ',
      );

      final proof = await gateway.confirmEmailVerification(
        challenge: challenge,
        code: '246810',
      );

      expect(proof.normalizedEmail, 'taylor@example.com');
      expect(proof.matches('TAYLOR@example.com'), isTrue);
      expect(challenge.maskedEmail, 't•••••@example.com');
      await expectLater(
        gateway.confirmEmailVerification(challenge: challenge, code: '246810'),
        throwsA(isA<ContactCongressVerificationException>()),
      );
    },
  );

  test(
    'binds address, email, human proof, and message to authorization',
    () async {
      final gateway = PreviewContactCongressVerificationGateway();
      final addressProof = await gateway.issueAddressProof(
        address: address,
        match: match,
      );
      final challenge = await gateway.startEmailVerification(
        'taylor@example.com',
      );
      final emailProof = await gateway.confirmEmailVerification(
        challenge: challenge,
        code: '246810',
      );
      final humanProof = await gateway.verifyHumanChallenge(
        action: 'contact_congress_send',
      );

      final authorization = await gateway.authorizeSend(
        CongressionalSendAuthorizationRequest(
          addressProof: addressProof,
          emailProof: emailProof,
          humanProof: humanProof,
          email: 'taylor@example.com',
          address: match.matchedAddress,
          recipients: const [recipient],
          topic: 'Education',
          subject: 'Support schools',
          message: 'Please support stable funding for public schools.',
          attestationVersion: 'contact-congress-v1',
          attestedAt: DateTime.now().toUtc(),
        ),
      );

      expect(authorization.token, startsWith('send-authorization-'));
      expect(authorization.idempotencyKey, startsWith('delivery-'));
      expect(
        authorization.expiresAt.difference(authorization.issuedAt),
        const Duration(minutes: 5),
      );
    },
  );

  test('rejects authorization when the confirmed email changed', () async {
    final gateway = PreviewContactCongressVerificationGateway();
    final addressProof = await gateway.issueAddressProof(
      address: address,
      match: match,
    );
    final challenge = await gateway.startEmailVerification(
      'taylor@example.com',
    );
    final emailProof = await gateway.confirmEmailVerification(
      challenge: challenge,
      code: '246810',
    );
    final humanProof = await gateway.verifyHumanChallenge(
      action: 'contact_congress_send',
    );

    await expectLater(
      gateway.authorizeSend(
        CongressionalSendAuthorizationRequest(
          addressProof: addressProof,
          emailProof: emailProof,
          humanProof: humanProof,
          email: 'different@example.com',
          address: match.matchedAddress,
          recipients: const [recipient],
          topic: 'Education',
          subject: 'Support schools',
          message: 'Please support stable funding for public schools.',
          attestationVersion: 'contact-congress-v1',
          attestedAt: DateTime.now().toUtc(),
        ),
      ),
      throwsA(isA<ContactCongressVerificationException>()),
    );
  });
}
