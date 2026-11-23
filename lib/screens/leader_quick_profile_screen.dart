import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Contact-first landing page. Extended records and jurisdiction data are a
/// separate destination, never part of the initial leader scroll.
class LeaderQuickProfileScreen extends StatelessWidget {
  final String name, role, jurisdiction;
  final String? party, phone, address, website, photoPath, recordedTerm;
  final VoidCallback onDetails;
  final Widget? statusPanel;
  final Widget? contactButton;
  const LeaderQuickProfileScreen({
    super.key,
    required this.name,
    required this.role,
    required this.jurisdiction,
    required this.onDetails,
    this.party,
    this.phone,
    this.address,
    this.website,
    this.photoPath,
    this.recordedTerm,
    this.statusPanel,
    this.contactButton,
  });

  Future<void> _open(BuildContext context, String value) async {
    final uri = Uri.tryParse(value);
    try {
      if (uri != null &&
          ['https', 'http', 'tel'].contains(uri.scheme) &&
          await launchUrl(uri, mode: LaunchMode.externalApplication))
        return;
    } catch (_) {
      /* Keep office details visible if the external app fails. */
    }
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open this office link. Please try again.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasPhone = phone?.trim().isNotEmpty ?? false;
    final hasWebsite = website?.trim().isNotEmpty ?? false;
    Widget avatar() => Container(
      width: 76,
      height: 76,
      color: colors.surfaceContainerHighest,
      child: Icon(
        Icons.person_outline,
        size: 38,
        color: colors.onSurfaceVariant,
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leader profile', style: TextStyle(fontSize: 17)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipOval(
                      child: photoPath == null
                          ? avatar()
                          : Image.asset(
                              'assets/img/$photoPath',
                              width: 76,
                              height: 76,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => avatar(),
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '$role · $jurisdiction',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (party?.isNotEmpty ?? false)
                            Text(
                              party!,
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (statusPanel != null) statusPanel!,
                if (contactButton != null) contactButton!,
                const SizedBox(height: 20),
                if (recordedTerm?.isNotEmpty ?? false) ...[
                  Text(
                    'Recorded term',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(recordedTerm!, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 20),
                ],
                const Text(
                  'Contact the office',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (hasPhone)
                  FilledButton.icon(
                    key: const Key('leader_call_office'),
                    onPressed: () => _open(
                      context,
                      'tel:${phone!.replaceAll(RegExp(r'[^0-9+]'), '')}',
                    ),
                    icon: const Icon(Icons.phone_outlined),
                    label: Text('Call office · $phone'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 15,
                      ),
                    ),
                  ),
                if (hasWebsite) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('leader_official_website'),
                    onPressed: () => _open(context, website!),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Official office website'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(15),
                    ),
                  ),
                ],
                if (!hasPhone && !hasWebsite)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Contact details are not supplied in this office record.',
                    ),
                  ),
                if (address?.isNotEmpty ?? false)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on_outlined),
                    title: const Text(
                      'Office address',
                      style: TextStyle(fontSize: 13),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SelectableText(address!),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                const SizedBox(height: 18),
                const Divider(),
                ListTile(
                  key: const Key('leader_details_button'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.insights_outlined),
                  title: const Text('Details'),
                  subtitle: Text(
                    role == 'Governor'
                        ? 'Office, activity, state data & sources'
                        : 'Office, jurisdiction, records & sources',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onDetails,
                ),
                const SizedBox(height: 12),
                Text(
                  'From the app’s recorded office profile. Confirm current details on the official office website.',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
