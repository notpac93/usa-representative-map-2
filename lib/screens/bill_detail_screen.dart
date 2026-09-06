import 'package:flutter/material.dart';
import '../data/bill_models.dart';
import '../data/civic_data_provider.dart';

class BillDetailScreen extends StatelessWidget {
  final BillRecord bill;

  const BillDetailScreen({Key? key, required this.bill}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = CivicDataProvider();
    final votes = provider.getVotesForBill(bill.id);

    return Scaffold(
      appBar: AppBar(title: Text(bill.title)),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'Status: ${bill.status}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (bill.upcomingDate != null)
            Text(
              'Upcoming Date: ${bill.upcomingDate}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          const SizedBox(height: 16),
          Text('Description', style: Theme.of(context).textTheme.titleLarge),
          Text(bill.description),
          const SizedBox(height: 24),
          Text('Sponsors', style: Theme.of(context).textTheme.titleLarge),
          if (bill.sponsorIds.isEmpty)
            const Text('No sponsors listed.')
          else
            ...bill.sponsorIds.map(
              (id) => ListTile(
                title: Text(id), // Ideally we look up the lawmaker name
                subtitle: Text('Sponsor'),
              ),
            ),
          const SizedBox(height: 24),
          Text(
            'Roll Call Votes',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (votes.isEmpty)
            const Text('No voting records found.')
          else
            ...votes.map(
              (v) => ListTile(
                title: Text(
                  v.lawmakerId,
                ), // Ideally we look up the lawmaker name
                trailing: Text(
                  v.vote,
                  style: TextStyle(
                    color: v.vote == 'Yea'
                        ? Colors.green
                        : (v.vote == 'Nay' ? Colors.red : Colors.grey),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
