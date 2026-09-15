import 'package:flutter_test/flutter_test.dart';
import 'package:usa_map_app/services/congressional_delivery_service.dart';

void main() {
  const house = CongressionalDeliveryRecipient(
    name: 'House Member',
    chamber: CongressionalChamber.house,
    officialUrl: 'https://member.house.gov/contact',
    bioguideId: 'H000001',
  );
  const senate = CongressionalDeliveryRecipient(
    name: 'Senator',
    chamber: CongressionalChamber.senate,
    officialUrl: 'https://senator.senate.gov/contact',
    bioguideId: 'S000001',
  );

  CongressionalDeliveryRequest request(String idempotencyKey) =>
      CongressionalDeliveryRequest(
        idempotencyKey: idempotencyKey,
        constituent: const CongressionalConstituent(
          fullName: 'Taylor Citizen',
          email: 'taylor@example.com',
          address: '123 Main St, Austin, TX 78701',
          state: 'Texas',
        ),
        topic: 'Education',
        subject: 'Support schools',
        message: 'Please support stable funding for public schools.',
        recipients: const [house, senate],
        authorizedAt: DateTime.utc(2026, 9, 15),
      );

  test(
    'placeholder mode returns an explicit unavailable result per office',
    () async {
      const gateway = PlaceholderCongressionalDeliveryGateway();

      final result = await gateway.submit(request('placeholder-1'));

      expect(gateway.canAttemptDirectDelivery, isFalse);
      expect(result.offices, hasLength(2));
      expect(
        result.offices.map((office) => office.status),
        everyElement(CongressionalDeliveryStatus.unavailable),
      );
      expect(
        result.offices,
        everyElement(
          predicate((office) {
            return (office as CongressionalOfficeDeliveryResult)
                .requiresOfficialSite;
          }),
        ),
      );
    },
  );

  test(
    'preserves mixed per-office outcomes without collapsing status',
    () async {
      final service = IdempotentCongressionalDeliveryService(
        _RecordingGateway((deliveryRequest) async {
          return CongressionalDeliveryResult(
            idempotencyKey: deliveryRequest.idempotencyKey,
            offices: const [
              CongressionalOfficeDeliveryResult(
                recipient: house,
                status: CongressionalDeliveryStatus.acceptedForRouting,
                message: 'Accepted by the House gateway for routing.',
                receiptId: 'house-receipt',
              ),
              CongressionalOfficeDeliveryResult(
                recipient: senate,
                status: CongressionalDeliveryStatus.needsUserAction,
                message: 'Finish on the senator’s official website.',
              ),
            ],
          );
        }),
      );

      final result = await service.submit(request('mixed-1'));

      expect(
        result.offices.first.status,
        CongressionalDeliveryStatus.acceptedForRouting,
      );
      expect(
        result.offices.last.status,
        CongressionalDeliveryStatus.needsUserAction,
      );
    },
  );

  test('same idempotency key reuses one in-flight submission', () async {
    var submissions = 0;
    final service = IdempotentCongressionalDeliveryService(
      _RecordingGateway((deliveryRequest) async {
        submissions++;
        return CongressionalDeliveryResult(
          idempotencyKey: deliveryRequest.idempotencyKey,
          offices: const [],
        );
      }),
    );

    final results = await Future.wait([
      service.submit(request('same-key')),
      service.submit(request('same-key')),
    ]);

    expect(submissions, 1);
    expect(results.first.wasDuplicate, isFalse);
    expect(results.last.wasDuplicate, isTrue);
  });
}

class _RecordingGateway implements CongressionalDeliveryGateway {
  _RecordingGateway(this.handler);

  final Future<CongressionalDeliveryResult> Function(
    CongressionalDeliveryRequest request,
  )
  handler;

  @override
  bool get canAttemptDirectDelivery => true;

  @override
  Future<CongressionalDeliveryResult> submit(
    CongressionalDeliveryRequest request,
  ) => handler(request);
}
