import '../widgets/leader_contact_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/data_provider.dart';
import '../data/models.dart';
import '../utils/search_handler.dart';
import 'lawmaker_detail_screen.dart';

enum DelegationChamber { senate, house }

typedef _DelegationMember = ({
  Object record,
  String name,
  String? party,
  String? photo,
  String? district,
});

class StateDelegationScreen extends StatelessWidget {
  const StateDelegationScreen({
    super.key,
    required this.stateId,
    required this.chamber,
  });

  final String stateId;
  final DelegationChamber chamber;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MapDataProvider>();
    final isSenate = chamber == DelegationChamber.senate;
    final isDelegate = !isSenate && stateId == 'DC';
    final role = isSenate
        ? 'Senator'
        : (isDelegate ? 'Delegate' : 'Representative');
    final title = isSenate ? 'U.S. Senate' : 'U.S. House';
    final stateName = SearchHandler.stateCodeToName[stateId] ?? stateId;
    final List<_DelegationMember> members = isSenate
        ? [
            for (final senator
                in provider.senators?[stateId] ?? const <Senator>[])
              (
                record: senator,
                name: senator.name,
                party: senator.party,
                photo: senator.photoLocalPath,
                district: null,
              ),
          ]
        : [
            for (final representative
                in provider.houseMembers?[stateId] ?? const <Representative>[])
              (
                record: representative,
                name: representative.name,
                party: representative.party,
                photo: representative.photoLocalPath,
                district: isDelegate
                    ? 'Nonvoting delegate'
                    : representative.district,
              ),
          ];

    return Scaffold(
      appBar: AppBar(title: Text('$stateName · $title')),
      body: SafeArea(
        child: members.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    isSenate && stateId == 'DC'
                        ? 'The District of Columbia has no U.S. Senate seats.'
                        : 'No serving members are listed for this delegation.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final photo = member.photo;
                      final subtitle = [
                        if (member.district case final district?
                            when district.isNotEmpty)
                          district,
                        if (member.party case final party?
                            when party.isNotEmpty)
                          party,
                      ].join(' · ');
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            foregroundImage: photo == null || photo.isEmpty
                                ? null
                                : AssetImage('assets/img/$photo'),
                            child: const Icon(Icons.person_outline),
                          ),
                          title: Text(member.name),
                          subtitle: subtitle.isEmpty ? null : Text(subtitle),
                          trailing: LeaderContactButton(leader: member.record),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => LawmakerDetailScreen(
                                lawmaker: member.record,
                                role: role,
                                stateId: stateId,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }
}
