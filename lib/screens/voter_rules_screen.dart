import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class VoterRulesScreen extends StatelessWidget {
  final String stateName;
  final String stateId;

  const VoterRulesScreen({
    super.key,
    required this.stateName,
    required this.stateId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Voter Rules & ID: $stateName"), elevation: 0),
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoCard(
              context,
              "Voter ID Requirements",
              "Laws regarding voter ID change frequently. We recommend checking the official state website before heading to the polls.",
              Icons.badge,
            ),
            const SizedBox(height: 24),
            _buildInfoCard(
              context,
              "Early Voting",
              "Many states offer early voting options, either in-person or via mail.",
              Icons.calendar_today,
            ),
            const SizedBox(height: 24),
            _buildInfoCard(
              context,
              "Absentee Voting",
              "Check if your state requires an excuse to request an absentee ballot.",
              Icons.mail,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                final url = Uri.parse("https://vote.gov/register/$stateId");
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text("View Official State Voting Portal"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    String title,
    String content,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: Theme.of(context).primaryColor),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
