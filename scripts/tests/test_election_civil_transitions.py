"""A lawful civil start day is a gate, never an invented effective instant."""
import copy
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import refresh_federal_officials as collector


class ElectionCivilTransitionTests(unittest.TestCase):
    def setUp(self):
        fixture = Path(__file__).parent / 'fixtures/federal_transition.json'
        self.snapshot = json.loads(fixture.read_text())
        self.term = self.snapshot['terms'][1]
        self.term.pop('scheduledStart', None)
        self.term.update(scheduledStartDate='2027-01-04', startTimeZone='America/Denver')

    def assumption(self, when):
        proof = copy.deepcopy(self.snapshot['evidence'][0])
        proof.update(id='civil-assumption', claim='assumedOffice',
                     personId=self.term['personId'], retrievedAt=self.snapshot['publishedAt'])
        self.snapshot['evidence'].append(proof)
        self.term['evidenceIds'].append(proof['id'])
        self.term['actualStart'] = when

    def test_utc_day_does_not_advance_official_local_day(self):
        self.snapshot['publishedAt'] = '2027-01-04T06:59:59Z'  # Still January 3 in Wyoming.
        collector.transition(self.snapshot)
        self.assertEqual(self.term['status'], 'incoming')
        self.assertFalse(collector.civil_start_is_due(self.term, collector.instant(self.snapshot['publishedAt'])))
        self.assertNotIn('scheduledStart', self.term)

    def test_due_civil_day_alone_never_promotes(self):
        self.snapshot['publishedAt'] = '2027-01-04T19:00:00Z'
        collector.transition(self.snapshot)
        self.assertEqual(self.term['status'], 'incoming')
        self.assertNotIn('actualStart', self.term)
        self.assertNotIn('scheduledStart', self.term)

    def test_fresh_actual_service_on_local_start_day_promotes(self):
        self.snapshot['publishedAt'] = '2027-01-04T19:00:00Z'
        self.assumption('2027-01-04T18:00:00Z')
        collector.transition(self.snapshot)
        self.assertEqual(self.term['status'], 'current')
        self.assertEqual(self.term['actualStart'], '2027-01-04T18:00:00Z')
        self.assertNotIn('scheduledStart', self.term)
        self.assertEqual(self.snapshot['terms'][0]['actualEnd'], self.term['actualStart'])
        once = copy.deepcopy(self.snapshot)
        self.assertEqual(collector.transition(self.snapshot), once)

    def test_actual_service_on_preceding_local_day_is_rejected(self):
        self.snapshot['publishedAt'] = '2027-01-04T19:00:00Z'
        self.assumption('2027-01-04T00:30:00Z')  # January 3 locally, despite UTC's January 4.
        with self.assertRaisesRegex(ValueError, 'precedes the verified local civil start date'):
            collector.transition(self.snapshot)
        self.assertEqual(self.term['status'], 'incoming')

    def test_early_assumption_cannot_bypass_a_future_civil_day(self):
        self.snapshot['publishedAt'] = '2027-01-03T18:00:00Z'
        self.assumption('2027-01-03T17:00:00Z')
        with self.assertRaisesRegex(ValueError, 'precedes the verified local civil start date'):
            collector.transition(self.snapshot)
        self.assertEqual(self.term['status'], 'incoming')

    def test_missing_or_invalid_zone_fails_closed(self):
        self.snapshot['publishedAt'] = '2027-01-04T19:00:00Z'
        for zone in (None, '', 'Government/UnverifiedZone'):
            with self.subTest(zone=zone):
                self.term['startTimeZone'] = zone
                with self.assertRaisesRegex(ValueError, 'time zone'):
                    collector.transition(self.snapshot)
                self.assertEqual(self.term['status'], 'incoming')

    def test_future_instant_remains_a_gate_when_both_precisions_exist(self):
        self.snapshot['publishedAt'] = '2027-01-04T19:00:00Z'
        self.term['scheduledStart'] = '2027-01-04T20:00:00Z'
        self.assumption('2027-01-04T18:00:00Z')
        collector.transition(self.snapshot)
        self.assertEqual(self.term['status'], 'incoming')

    def test_recognition_only_needs_same_local_day_gate(self):
        self.snapshot['publishedAt'] = '2027-01-04T06:00:00Z'
        self.term['status'] = 'incomingRecognized'
        collector.transition(self.snapshot)
        self.assertEqual(self.term['status'], 'incomingRecognized')


if __name__ == '__main__':
    unittest.main()
