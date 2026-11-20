import json
from pathlib import Path
import re
import unittest
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[2]
STATES = set('AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY'.split())


class StateElectionSourceRegistryTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.registry = json.loads((ROOT / 'scripts/data/state_election_sources.json').read_text())

    def test_all_fifty_unique_states_have_official_discovery(self):
        entries = self.registry['states']
        self.assertEqual(len(entries), 50)
        self.assertEqual({e['stateId'] for e in entries}, STATES)
        self.assertEqual(self.registry['discovery']['url'], 'https://www.usa.gov/state-election-office')
        self.assertRegex(self.registry['discovery']['sha256'], r'^[0-9a-f]{64}$')
        for entry in entries:
            self.assertEqual(entry['authoritySourceUrl'], self.registry['discovery']['url'])
            self.assertTrue(entry['name'].strip())

    def test_urls_require_https_and_exact_registered_hosts(self):
        for entry in self.registry['states']:
            for key in ('authorityUrl', 'resultsUrl'):
                u = urlparse(entry[key])
                self.assertEqual(u.scheme, 'https', entry['stateId'])
                self.assertFalse(u.username or u.password)
                self.assertIn(u.hostname, entry['allowedHosts'])
            self.assertEqual(len(entry['allowedHosts']), len(set(entry['allowedHosts'])))
            self.assertTrue(all('*' not in host and '/' not in host for host in entry['allowedHosts']))

    def test_reachability_is_separate_from_certification(self):
        self.assertIn('not a claim', self.registry['coverageMeaning'])
        for entry in self.registry['states']:
            self.assertIn('never proves', entry['certificationPolicy'])
            observation = entry['initialObservation']
            self.assertIn(observation['status'], ['retrieved','access_blocked','fetch_failed','not_retrieved'])
            self.assertNotIn('certified', observation)
            if observation['status']=='retrieved':
                self.assertRegex(observation['sha256'],r'^[0-9a-f]{64}$')

    def test_delegated_feeds_require_a_government_link_source(self):
        for entry in self.registry['states']:
            for feed in entry['machineReadableFeeds']:
                self.assertEqual(urlparse(feed['url']).scheme,'https')
                self.assertEqual(urlparse(feed['url']).hostname,feed['approvedHost'])
                provenance = urlparse(feed['officialLinkSource'])
                self.assertEqual(provenance.scheme,'https')
                self.assertIn(provenance.hostname,entry['allowedHosts'])
                self.assertIn(feed['resultStatus'], ['unofficial','requires_certification_document','official_results_certification_unverified'])


if __name__=='__main__':unittest.main()
