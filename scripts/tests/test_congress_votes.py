from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from scripts import congress_votes as votes


HOUSE_ROLL = b'''<rollcall-vote>
<vote-metadata><congress>119</congress><session>1st</session><rollcall-num>1</rollcall-num>
<legis-num>H R 42</legis-num><vote-question>On Agreeing to the Amendment</vote-question>
<amendment-num>17</amendment-num><action-date>3-Jan-2025</action-date><vote-result>Passed</vote-result>
<vote-totals><totals-by-vote><aye-total>1</aye-total><no-total>0</no-total><present-total>1</present-total>
<not-voting-total>1</not-voting-total></totals-by-vote></vote-totals></vote-metadata>
<vote-data>
<recorded-vote><legislator name-id="A000001" state="NY" party="D" district="01">Member A</legislator><vote>Aye</vote></recorded-vote>
<recorded-vote><legislator name-id="B000001" state="NY" party="R">Member B</legislator><vote>Present</vote></recorded-vote>
<recorded-vote><legislator name-id="C000001" state="NY" party="R">Member C</legislator><vote>Not Voting</vote></recorded-vote>
</vote-data></rollcall-vote>'''

SENATE_ROLL = b'''<roll_call_vote>
<congress>119</congress><session>1</session><vote_number>1</vote_number>
<vote_date>July 29, 2025, 07:12 PM</vote_date><vote_question_text>On the Cloture Motion</vote_question_text>
<vote_title>Motion to invoke cloture on the amendment</vote_title><vote_result_text>Agreed to</vote_result_text>
<document><document_type>S.Amdt.</document_type><document_number>92</document_number></document>
<amendment><amendment_number>S.Amdt. 92</amendment_number><amendment_to_document_number>H.R. 42</amendment_to_document_number></amendment>
<count><yeas>2</yeas><nays>1</nays><present>0</present><absent>1</absent></count>
<tie_breaker><by_whom>Vice President</by_whom><tie_breaker_vote>Yea</tie_breaker_vote></tie_breaker>
<members>
<member><lis_member_id>S001</lis_member_id><first_name>First</first_name><last_name>One</last_name><state>CA</state><party>D</party><vote_cast>Yea</vote_cast></member>
<member><lis_member_id>S002</lis_member_id><last_name>Two</last_name><state>CA</state><party>R</party><vote_cast>Nay</vote_cast></member>
<member><lis_member_id>S003</lis_member_id><last_name>Three</last_name><state>NY</state><party>D</party><vote_cast>Not Voting</vote_cast></member>
</members></roll_call_vote>'''

BILL = b'''<billStatus><bill><congress>119</congress><type>HR</type><number>42</number><title>Test measure</title>
<subjects><legislativeSubjects><item><name>Taxation</name></item></legislativeSubjects></subjects>
<latestAction><actionDate>2025-01-03</actionDate><text>Referred.</text></latestAction>
<summaries><summary><actionDate>2025-01-03</actionDate><actionDesc>Introduced in House</actionDesc>
<text><![CDATA[<p>First &amp; second.</p><p>Third.</p>]]></text></summary></summaries>
</bill></billStatus>'''


class Source:
    def __init__(self, responses):
        self.responses = responses

    def get(self, url, hours=0, allow_missing=False):
        if allow_missing:
            return self.responses.get(url)
        return self.responses[url]


class CongressionalVotesTest(unittest.TestCase):
    def test_house_keeps_amendment_and_separates_present_from_not_voting(self):
        key, vote = votes.house_record(HOUSE_ROLL, 119, 1, 1, 2025)
        self.assertEqual(key, (119, 'hr', 42))
        self.assertEqual(vote['amendment'], '17')
        self.assertEqual(vote['counts'], {'yes': 1, 'no': 0, 'present': 1, 'notVoting': 1})
        self.assertEqual([m['id'] for m in vote['members'] if m['position'] == 'notVoting'], ['C000001'])

    def test_senate_uses_explicit_amendment_parent_and_keeps_vp_separate(self):
        key, vote = votes.senate_record(SENATE_ROLL, 119, 1, 1)
        self.assertEqual(key, (119, 'hr', 42))
        self.assertEqual(vote['date'], '2025-07-29')
        self.assertEqual(vote['tieBreaker'], 'Yea')
        self.assertEqual(vote['counts'], {'yes': 1, 'no': 1, 'present': 0, 'notVoting': 1})

    def test_senate_empty_absent_tally_is_zero(self):
        raw = SENATE_ROLL.replace(b'<absent>1</absent>', b'<absent/>')
        raw = raw[:raw.index(b'<member><lis_member_id>S003')] + b'</members></roll_call_vote>'
        _, roll = votes.senate_record(raw, 119, 1, 1)
        self.assertEqual(roll['counts']['notVoting'], 0)

    def test_mismatched_totals_and_wrong_roll_fail_validation(self):
        bad = HOUSE_ROLL.replace(b'<not-voting-total>1', b'<not-voting-total>4')
        with self.assertRaisesRegex(ValueError, 'disagree'):
            votes.house_record(bad, 119, 1, 1, 2025)
        with self.assertRaisesRegex(ValueError, 'identity mismatch'):
            votes.senate_record(SENATE_ROLL, 119, 1, 2)

    def test_does_not_guess_bill_or_nonvoter_from_unrelated_record(self):
        nomination = SENATE_ROLL.replace(b'<amendment_to_document_number>H.R. 42', b'<amendment_to_document_number>')
        self.assertIsNone(votes.senate_record(nomination, 119, 1, 1))
        self.assertIsNone(votes.bill_key(119, 'PN 42'))
        self.assertIsNone(votes.bill_key(119, 'H.Amdt. 42'))

    def test_govinfo_summary_keeps_plain_text_and_version(self):
        metadata = votes.bill_details(BILL, (119, 'hr', 42))
        self.assertEqual(metadata['subjects'], ['Taxation'])
        self.assertEqual(metadata['summaries'][0]['stage'], 'Introduced in House')
        self.assertEqual(metadata['summaries'][0]['text'], 'First & second.\n\nThird.')
        with self.assertRaisesRegex(ValueError, 'identity mismatch'):
            votes.bill_details(BILL, (119, 'hr', 43))

    def test_discovery_does_not_accept_a_known_gap(self):
        with ThreadPoolExecutor() as executor, self.assertRaisesRegex(ValueError, 'missing Clerk roll calls'):
            votes.house_rolls(Source({
                f'{votes.HOUSE}/Votes/MemberVotes?CongressNum=119&Session=1st': b'<html/>',
            }), 119, 1, [1], False, executor)

    def test_senate_explicit_unavailable_page_is_pending(self):
        source = Source({
            f'{votes.SENATE}/roll_call_lists/vote_menu_119_1.xml':
                b'<vote_summary><congress>119</congress><session>1</session><votes><vote><vote_number>1</vote_number></vote></votes></vote_summary>',
            f'{votes.SENATE}/roll_call_votes/vote1191/vote_119_1_00001.xml': votes.SENATE_PENDING_PAGE,
        })
        with ThreadPoolExecutor() as executor:
            self.assertEqual(votes.senate_rolls(source, 119, 1, [], False, executor), {1: votes.PENDING})

    def test_two_chambers_publish_versioned_detail_for_one_bill(self):
        source = Source({
            f'{votes.HOUSE}/Votes/MemberVotes?CongressNum=119&Session=1st': b'<a href="/Votes/20251">Vote</a>',
            f'{votes.HOUSE}/evs/2025/roll001.xml': HOUSE_ROLL,
            f'{votes.SENATE}/roll_call_lists/vote_menu_119_1.xml':
                b'<vote_summary><congress>119</congress><session>1</session><votes><vote><vote_number>1</vote_number></vote></votes></vote_summary>',
            f'{votes.SENATE}/roll_call_votes/vote1191/vote_119_1_00001.xml': SENATE_ROLL,
            f'{votes.GOVINFO}/bulkdata/BILLSTATUS/119/hr/BILLSTATUS-119hr42.xml': BILL,
        })
        with TemporaryDirectory() as directory, ThreadPoolExecutor() as executor:
            result = votes.refresh(source, Path(directory), 119, votes.date(2025, 10, 1), executor, {})
            self.assertEqual(len(result['bills']), 1)
            entry = result['bills'][0]
            self.assertEqual(entry['chambers'], ['House', 'Senate'])
            self.assertTrue((Path(directory) / entry['path']).is_file())


if __name__ == '__main__':
    unittest.main()
