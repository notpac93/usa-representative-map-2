import 'package:flutter/material.dart';

import '../data/models.dart';
import '../design/civic_palette.dart';
import '../screens/contact_congress_screen.dart';
import '../services/congressional_delivery_service.dart';

/// The shared entry point from a congressional result or profile.
class DirectMessageButton extends StatelessWidget {
  const DirectMessageButton({
    super.key,
    required this.recipient,
    required this.stateId,
  });

  factory DirectMessageButton.forOfficial({
    Key? key,
    required Object official,
    required String stateId,
  }) {
    final ContactCongressRecipient recipient;
    if (official is Senator) {
      recipient = ContactCongressRecipient(
        name: official.name,
        role: 'U.S. Senator',
        officialUrl: official.contactUrl ?? official.website ?? '',
        bioguideId: official.bioguideId,
        photoAsset: official.photoLocalPath == null
            ? null
            : 'assets/img/${official.photoLocalPath}',
        chamber: CongressionalChamber.senate,
      );
    } else if (official is Representative) {
      recipient = ContactCongressRecipient(
        name: official.name,
        role: 'U.S. Representative',
        officialUrl: official.contactUrl ?? official.website ?? '',
        bioguideId: official.bioguideId,
        photoAsset: official.photoLocalPath == null
            ? null
            : 'assets/img/${official.photoLocalPath}',
        chamber: CongressionalChamber.house,
      );
    } else {
      throw ArgumentError('Direct Message requires a congressional official');
    }
    return DirectMessageButton(
      key: key,
      recipient: recipient,
      stateId: stateId,
    );
  }

  final ContactCongressRecipient recipient;
  final String stateId;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    icon: const Icon(Icons.send_outlined, size: 18),
    label: const Text('Direct Message'),
    style: FilledButton.styleFrom(
      backgroundColor: CivicPalette.teal,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 44),
    ),
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ContactCongressScreen(
          stateName: stateId,
          directoryContact: true,
          recipients: [recipient],
        ),
      ),
    ),
  );
}
