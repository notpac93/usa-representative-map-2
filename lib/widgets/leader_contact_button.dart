import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';

class LeaderContactButton extends StatelessWidget {
  const LeaderContactButton({super.key, required this.leader})
    : form = null,
      phone = null,
      website = null;
  const LeaderContactButton.contacts({
    super.key,
    this.form,
    this.phone,
    this.website,
  }) : leader = null;

  final Object? leader;
  final String? form, phone, website;

  Uri? _webLink(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      return null;
    }
    return uri;
  }

  @override
  Widget build(BuildContext context) {
    final (contactForm, contactPhone, contactWebsite) = switch (leader) {
      Senator s => (s.contactUrl, s.phone, s.website),
      Representative r => (r.contactUrl, r.phone, r.website),
      Governor g => (null, g.phone, g.website),
      Mayor m => (null, null, m.detailsUrl),
      _ => (form, phone, website),
    };
    final number = contactPhone?.replaceAll(RegExp(r'[^0-9+]'), '') ?? '';
    final uri =
        _webLink(contactForm) ??
        (RegExp(r'[0-9]').hasMatch(number)
            ? Uri(scheme: 'tel', path: number)
            : _webLink(contactWebsite));
    if (uri == null) return const SizedBox.shrink();

    return TextButton(
      onPressed: () async {
        try {
          if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
            return;
          }
        } catch (_) {
          // Report failed launches below.
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open this office contact.'),
            ),
          );
        }
      },
      child: const Text('Contact'),
    );
  }
}
