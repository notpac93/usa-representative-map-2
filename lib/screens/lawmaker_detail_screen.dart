import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/models.dart';

class LawmakerDetailScreen extends StatelessWidget {
  final dynamic lawmaker; // Governor, Senator, or Representative
  final String role;

  const LawmakerDetailScreen({
    super.key,
    required this.lawmaker,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    String name = '';
    String? party;
    String? photoLocalPath;
    String? phone;
    String? address;
    String? website;
    List<String> extraInfo = [];

    if (lawmaker is Governor) {
      final g = lawmaker as Governor;
      name = g.name;
      party = g.party;
      photoLocalPath = g.photoLocalPath;
      phone = g.phone;
      address = g.address;
      if (g.terms.isNotEmpty) {
        extraInfo.add("Terms:\n${g.terms.join('\n')}");
      }
    } else if (lawmaker is Senator) {
      final s = lawmaker as Senator;
      name = s.name;
      party = s.party;
      photoLocalPath = s.photoLocalPath;
      phone = s.phone;
      address = s.address;
      website = s.website;
    } else if (lawmaker is Representative) {
      final r = lawmaker as Representative;
      name = r.name;
      party = r.party;
      photoLocalPath = r.photoLocalPath;
      phone = r.phone;
      address = r.office; // Representatives usually have "office"
      website = r.website;
      if (r.district != null) {
        extraInfo.add("District: ${r.district}");
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Photo
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade200,
                image: photoLocalPath != null
                    ? DecorationImage(
                        image: AssetImage('assets/img/$photoLocalPath'),
                        fit: BoxFit.cover,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: photoLocalPath == null
                  ? Icon(Icons.person, size: 100, color: Colors.grey.shade400)
                  : null,
            ),
            const SizedBox(height: 24),

            // Name & Role
            Text(
              name,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "$role ${party != null ? '• $party' : ''}",
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),

            // Info Cards
            _buildInfoCard(context, Icons.phone, "Phone", phone),
            _buildInfoCard(context, Icons.location_on, "Office", address),
            _buildInfoCard(
              context,
              Icons.language,
              "Website",
              website,
              isLink: true,
            ),

            // Extra Info (Terms, District)
            if (extraInfo.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...extraInfo.map(
                (info) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Card(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        info,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    IconData icon,
    String label,
    String? value, {
    bool isLink = false,
  }) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        color: Colors.grey.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: InkWell(
          onTap: isLink
              ? () async {
                  final uri = Uri.tryParse(value);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text(
                        value,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: isLink ? Colors.blue : null,
                          decoration: isLink ? TextDecoration.underline : null,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLink)
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
