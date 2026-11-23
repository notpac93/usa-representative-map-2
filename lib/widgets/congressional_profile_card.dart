import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/civic_palette.dart';

/// Identity and the most useful contact details in one compact surface.
class CongressionalProfileCard extends StatelessWidget {
  const CongressionalProfileCard({
    super.key,
    required this.name,
    required this.role,
    required this.jurisdiction,
    this.party,
    this.photoAsset,
    this.phone,
    this.address,
    this.website,
    this.contactUrl,
    this.fax,
    this.email,
  });

  final String name, role, jurisdiction;
  final String? party,
      photoAsset,
      phone,
      address,
      website,
      contactUrl,
      fax,
      email;

  String? get _partyLabel => switch (party) {
    'D' => 'Democratic Party',
    'R' => 'Republican Party',
    'I' => 'Independent',
    _ => party,
  };

  Future<void> _open(BuildContext context, Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Report the action failure without logging contact information.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This contact link could not be opened.')),
      );
    }
  }

  Widget _contact(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Uri? uri,
  }) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: CivicPalette.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CivicPalette.mutedInk,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: CivicPalette.navy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return uri == null
        ? content
        : Semantics(
            link: true,
            child: InkWell(onTap: () => _open(context, uri), child: content),
          );
  }

  Uri? _webUri(String? value) {
    final uri = Uri.tryParse(value ?? '');
    return uri != null &&
            ['https', 'http'].contains(uri.scheme) &&
            uri.host.isNotEmpty
        ? uri
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final websiteUri = _webUri(website);
    final contactUri = _webUri(contactUrl);
    final fallback = Container(
      color: CivicPalette.tealTint,
      child: const Icon(
        Icons.person_outline,
        size: 42,
        color: CivicPalette.teal,
      ),
    );
    final identity = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 76,
            height: 94,
            child: photoAsset == null
                ? fallback
                : Image.asset(
                    photoAsset!,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    semanticLabel: 'Portrait of $name',
                    errorBuilder: (context, error, stackTrace) => fallback,
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  color: CivicPalette.navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                role,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CivicPalette.navy,
                ),
              ),
              Text(
                jurisdiction,
                style: const TextStyle(
                  fontSize: 15,
                  color: CivicPalette.mutedInk,
                ),
              ),
              if (_partyLabel?.isNotEmpty == true)
                Text(
                  _partyLabel!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: CivicPalette.mutedInk,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    final contacts = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (phone?.isNotEmpty == true)
          _contact(
            context,
            Icons.phone_outlined,
            'Phone',
            phone!,
            uri: Uri(
              scheme: 'tel',
              path: phone!.replaceAll(RegExp(r'[^\d+]'), ''),
            ),
          ),
        if (fax?.isNotEmpty == true)
          _contact(context, Icons.print_outlined, 'Fax', fax!),
        if (email?.isNotEmpty == true)
          _contact(
            context,
            Icons.email_outlined,
            'Email',
            email!,
            uri: Uri(scheme: 'mailto', path: email),
          ),
        if (address?.isNotEmpty == true)
          _contact(context, Icons.location_on_outlined, 'Office', address!),
        if (websiteUri != null || contactUri != null)
          Wrap(
            spacing: 8,
            children: [
              if (websiteUri != null)
                TextButton.icon(
                  onPressed: () => _open(context, websiteUri),
                  icon: const Icon(Icons.language, size: 18),
                  label: const Text('Official website'),
                ),
              if (contactUri != null && contactUri != websiteUri)
                TextButton.icon(
                  onPressed: () => _open(context, contactUri),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Office contact form'),
                ),
            ],
          ),
      ],
    );
    return Container(
      key: const Key('congressional-profile-card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 650
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 28),
                  Expanded(child: contacts),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [identity, const SizedBox(height: 12), contacts],
              ),
      ),
    );
  }
}
