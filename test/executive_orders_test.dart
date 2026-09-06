import 'package:flutter_test/flutter_test.dart';
import 'package:usa_map_app/data/bill_models.dart';
import 'package:usa_map_app/data/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Executive Orders & President Model Tests', () {
    test('ExecutiveOrderRecord parses official Federal Register JSON format properly', () {
      final jsonSample = {
        "id": "EO-14423",
        "orderNumber": "14423",
        "title": "Establishing the United States Space Academy",
        "signingDate": "2026-08-28",
        "publicationDate": "2026-09-03",
        "president": "Donald Trump",
        "presidentId": "donald-trump",
        "citation": "91 FR 56737",
        "url": "https://www.federalregister.gov/documents/2026/09/03/2026-18141/establishing-the-united-states-space-academy",
        "pdfUrl": "https://www.govinfo.gov/content/pkg/FR-2026-09-03/pdf/2026-18141.pdf",
        "summary": "Directs the establishment of the space academy."
      };

      final record = ExecutiveOrderRecord.fromJson(jsonSample);

      expect(record.id, 'EO-14423');
      expect(record.orderNumber, '14423');
      expect(record.title, 'Establishing the United States Space Academy');
      expect(record.signingDate, '2026-08-28');
      expect(record.publicationDate, '2026-09-03');
      expect(record.president, 'Donald Trump');
      expect(record.presidentId, 'donald-trump');
      expect(record.citation, '91 FR 56737');
      expect(record.pdfUrl, contains('govinfo.gov'));
      expect(record.url, contains('federalregister.gov'));
      expect(record.summary, isNotNull);
    });

    test('President model parses correctly from JSON', () {
      final jsonSample = {
        "id": "donald-trump",
        "name": "Donald J. Trump",
        "ordinal": "47th President of the United States",
        "party": "Republican",
        "current": true,
        "terms": ["2025–Present", "2017–2021"],
        "vicePresident": "JD Vance",
        "website": "https://www.whitehouse.gov",
        "bio": "47th President."
      };

      final president = President.fromJson(jsonSample);

      expect(president.id, 'donald-trump');
      expect(president.name, 'Donald J. Trump');
      expect(president.ordinal, '47th President of the United States');
      expect(president.party, 'Republican');
      expect(president.current, isTrue);
      expect(president.terms.length, 2);
      expect(president.vicePresident, 'JD Vance');
      expect(president.website, 'https://www.whitehouse.gov');
    });

    test('ExecutiveOrderRecord correctly parses disposition notes and status flags', () {
      final revokedSample = {
        "id": "EO-14143",
        "orderNumber": "14143",
        "title": "Providing for the Appointment of Alumni of AmeriCorps",
        "signingDate": "2025-01-16",
        "publicationDate": "2025-01-17",
        "president": "Joseph R. Biden Jr.",
        "presidentId": "joe-biden",
        "citation": "90 FR 6751",
        "url": "https://www.federalregister.gov/documents/2025/01/17/2025-01467",
        "pdfUrl": "https://www.govinfo.gov/content/pkg/FR-2025-01-17/pdf/2025-01467.pdf",
        "dispositionNotes": "Revoked by: EO 14148, January 20, 2025",
        "status": "Revoked",
        "statusDetails": "Revoked by EO 14148, January 20, 2025"
      };

      final record = ExecutiveOrderRecord.fromJson(revokedSample);
      expect(record.status, 'Revoked');
      expect(record.isRevoked, isTrue);
      expect(record.isInEffect, isFalse);
      expect(record.dispositionNotes, contains('EO 14148'));
      expect(record.statusDetails, contains('Revoked by'));
    });
  });
}
