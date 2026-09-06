import 'package:flutter/material.dart';
import '../data/civic_data_provider.dart';
import '../screens/president_detail_screen.dart';

class ExecutiveBranchWidget extends StatelessWidget {
  const ExecutiveBranchWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = CivicDataProvider();
    final president = provider.getCurrentPresident();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PresidentDetailScreen(
                initialPresident: president,
              ),
            ),
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.account_balance,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "The President",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  president != null ? "${president.name} • Orders" : "Executive Orders",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blueGrey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: Colors.blueGrey,
            ),
          ],
        ),
      ),
    );
  }
}
