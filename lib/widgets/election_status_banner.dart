import 'package:flutter/material.dart';
import '../data/bill_models.dart';

/// Describes a recorded election without guessing its results or next cycle.
class ElectionStatusBanner extends StatelessWidget {
  final ElectionRecord election;
  final DateTime now;
  final VoidCallback? onOfficialInformation;
  const ElectionStatusBanner({
    super.key,
    required this.election,
    required this.now,
    this.onOfficialInformation,
  });

  @override
  Widget build(BuildContext context) {
    final phase = election.phaseOn(now);
    final upcoming = phase == ElectionPhase.upcoming;
    return Container(
      key: const Key('election_status_banner'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            election.statusLabelOn(now),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          if (election.recordedElectionDate != null) ...[
            const SizedBox(height: 5),
            Text(
              '${election.nextElectionDate.isEmpty ? election.electionDateIso : election.nextElectionDate} • ${election.electionType}',
            ),
          ],
          if (phase == ElectionPhase.held) ...[
            const SizedBox(height: 6),
            Text(election.resultsStatusLabel),
            const SizedBox(height: 6),
            const Text(
              'These election dates and deadlines are historical. A future election date has not been verified here.',
            ),
          ],
          if (phase == ElectionPhase.undated)
            const Text(
              'Check the official election office for the next election and current voting deadlines.',
            ),
          if (upcoming) ...[
            if (election.voterRegistrationDeadline.isNotEmpty)
              Text(
                'Recorded registration deadline: ${election.voterRegistrationDeadline}',
              ),
            if (election.earlyVotingStart.isNotEmpty)
              Text('Recorded early voting start: ${election.earlyVotingStart}'),
          ],
          if (onOfficialInformation != null)
            TextButton.icon(
              onPressed: onOfficialInformation,
              icon: const Icon(Icons.open_in_new, size: 15),
              label: const Text('Official election information'),
            ),
        ],
      ),
    );
  }
}
