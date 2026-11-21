import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

typedef _Record = Map<String, dynamic>;

const _feed = String.fromEnvironment(
  'CONGRESS_VOTES_FEED_URL',
  defaultValue:
      'https://raw.githubusercontent.com/notpac93/usa-representative-map-2/congress-votes-data/',
);
const _positions = <String, (String, Color)>{
  'yes': ('Yea / Aye', Color(0xFF08765D)),
  'no': ('Nay / No', Color(0xFFAA3344)),
  'present': ('Present', Color(0xFF7C57A5)),
  'notVoting': ('Not Voting', Color(0xFF6B7280)),
};

List<_Record> _records(Object? value) =>
    (value as List<dynamic>).cast<_Record>();

Future<_Record> _getRecord(String path, http.Client? client) async {
  final uri = Uri.parse('$_feed$path');
  final response = await (client?.get(uri) ?? http.get(uri)).timeout(
    const Duration(seconds: 15),
  );
  if (response.statusCode != 200) {
    throw FormatException(
      'Congressional data unavailable (${response.statusCode})',
    );
  }
  return jsonDecode(utf8.decode(response.bodyBytes)) as _Record;
}

Future<_Record> _loadIndex(http.Client? client) async {
  final record = await _getRecord('index.json', client);
  if (record['schema'] != 1) {
    throw const FormatException('Unsupported congressional data version');
  }
  return record;
}

class CongressVotesScreen extends StatefulWidget {
  const CongressVotesScreen({super.key, this.client});
  final http.Client? client;

  @override
  State<CongressVotesScreen> createState() => _CongressVotesScreenState();
}

class _CongressVotesScreenState extends State<CongressVotesScreen> {
  late Future<_Record> _index = _loadIndex(widget.client);
  int? _congress;
  String _query = '';
  String? _chamber;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bills & roll calls')),
      body: FutureBuilder<_Record>(
        future: _index,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _Retry(
              message: 'The congressional vote feed is unavailable.',
              onRetry: () => setState(() => _index = _loadIndex(widget.client)),
            );
          }
          final index = snapshot.data!;
          final congresses = _records(index['congresses']);
          if (congresses.isEmpty) {
            return const Center(
              child: Text('No roll calls published in the feed yet.'),
            );
          }
          final term = congresses.firstWhere(
            (row) => row['congress'] == _congress,
            orElse: () => congresses.first,
          );
          final pending = (term['pendingRolls'] as _Record? ?? {}).values
              .fold<int>(0, (total, rolls) => total + (rolls as List).length);
          final query = _query.toLowerCase().trim();
          final referenceQuery = query.replaceAll(RegExp(r'[.\s-]'), '');
          final bills = _records(term['bills']).where((row) {
            final label = (row['label'] as String).toLowerCase().replaceAll(
              RegExp(r'[.\s-]'),
              '',
            );
            return (_chamber == null ||
                    (row['chambers'] as List).contains(_chamber)) &&
                ((row['title'] as String).toLowerCase().contains(query) ||
                    label.contains(referenceQuery));
          }).toList();
          final updated = DateTime.tryParse(
            index['checkedAt'] as String? ?? '',
          )?.toLocal();
          final checked = updated == null
              ? 'Update time unavailable'
              : 'Sources checked ${MaterialLocalizations.of(context).formatMediumDate(updated)}';
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: bills.isEmpty ? 2 : bills.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Explore recorded House and Senate votes on bills and resolutions. Individual voting records are available for roll calls.',
                        ),
                        const SizedBox(height: 8),
                        Text(checked),
                        if (pending > 0)
                          Text(
                            'Chamber details pending for $pending indexed roll ${pending == 1 ? 'call' : 'calls'}.',
                          ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 20,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            DropdownButton<int>(
                              value: term['congress'] as int,
                              items: congresses.map((row) {
                                final number = row['congress'] as int;
                                return DropdownMenuItem(
                                  value: number,
                                  child: Text('Congress $number'),
                                );
                              }).toList(),
                              onChanged: (number) =>
                                  setState(() => _congress = number),
                            ),
                            for (final chamber in ['House', 'Senate'])
                              FilterChip(
                                label: Text(chamber),
                                selected: _chamber == chamber,
                                onSelected: (selected) => setState(
                                  () => _chamber = selected ? chamber : null,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          onChanged: (value) => setState(() => _query = value),
                          decoration: const InputDecoration(
                            labelText: 'Search by bill title or number',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('${bills.length} measures'),
                        const SizedBox(height: 8),
                      ],
                    );
                  }
                  if (bills.isEmpty) {
                    return const ListTile(
                      title: Text('No bills match these filters.'),
                    );
                  }
                  final bill = bills[index - 1];
                  final label = bill['label'] as String;
                  final title = bill['title'] as String;
                  final chambers = (bill['chambers'] as List).join(' · ');
                  final rolls = (bill['rollIds'] as List).length;
                  return Card(
                    child: ListTile(
                      title: Text(title == label ? label : '$label · $title'),
                      subtitle: Text(
                        '$chambers · $rolls roll ${rolls == 1 ? 'call' : 'calls'}\nLatest roll call ${bill['latestVote']}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _BillVotesScreen(
                            bill: bill,
                            preferredChamber: _chamber,
                            client: widget.client,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BillVotesScreen extends StatefulWidget {
  const _BillVotesScreen({
    required this.bill,
    required this.client,
    this.preferredChamber,
  });
  final http.Client? client;
  final _Record bill;
  final String? preferredChamber;

  @override
  State<_BillVotesScreen> createState() => _BillVotesScreenState();
}

class _BillVotesScreenState extends State<_BillVotesScreen> {
  late final Future<Map<String, String>> _houseNames = _loadHouseNames();

  Future<Map<String, String>> _loadHouseNames() async {
    try {
      final groups = _records(
        jsonDecode(
          await rootBundle.loadString('assets/data/houseMembers.json'),
        ),
      );
      return {
        for (final group in groups)
          for (final member in _records(group['representatives']))
            if (member['bioguideId'] case final String id)
              if (member['name'] case final String name) id: name,
      };
    } on Exception {
      return {};
    }
  }

  late Future<_Record> _bill = _loadBill();
  int? _selectedRoll;

  Future<_Record> _loadBill() async {
    final detail = await _getRecord(
      widget.bill['path'] as String,
      widget.client,
    );
    if (detail['id'] != widget.bill['id']) {
      throw const FormatException('Congressional bill identity mismatch');
    }
    return detail;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.bill['label'] as String)),
      body: FutureBuilder<_Record>(
        future: _bill,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _Retry(
              message: 'The bill details could not be loaded.',
              onRetry: () => setState(() => _bill = _loadBill()),
            );
          }
          final bill = snapshot.data!;
          final votes = _records(bill['votes']);
          final preferred = votes.indexWhere(
            (vote) => vote['chamber'] == widget.preferredChamber,
          );
          final selected = _selectedRoll ?? (preferred < 0 ? 0 : preferred);
          final roll = votes[selected];
          final metadata = bill['metadata'] as _Record?;
          final summaries = metadata == null
              ? <_Record>[]
              : _records(metadata['summaries']);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    bill['title'] as String,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'What the bill does',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (summaries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'An official bill summary is unavailable. See the bill text on Congress.gov.',
                      ),
                    )
                  else
                    for (final summary in summaries)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          'CRS summary · ${summary['stage']} · ${summary['date']}',
                        ),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        expandedAlignment: Alignment.centerLeft,
                        children: [SelectableText(summary['text'] as String)],
                      ),
                  if (metadata != null) _BillMetadata(metadata: metadata),
                  Wrap(
                    spacing: 8,
                    children: [
                      _SourceLink(
                        label: 'Bill on Congress.gov',
                        url: bill['congressUrl'] as String,
                      ),
                      _SourceLink(
                        label: 'Official bill text',
                        url: "${bill['congressUrl']}/text",
                      ),
                      if (metadata != null)
                        _SourceLink(
                          label: 'GovInfo bill status XML',
                          url: bill['metadataUrl'] as String,
                        ),
                    ],
                  ),
                  const Divider(height: 32),
                  Text(
                    'Recorded roll calls',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select a roll call',
                      border: OutlineInputBorder(),
                    ),
                    items: votes.indexed.map((entry) {
                      final (index, vote) = entry;
                      return DropdownMenuItem(
                        value: index,
                        child: Text(
                          '${vote['chamber']} · ${vote['date']} · Roll ${vote['roll']} · ${vote['question']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (index) => setState(() => _selectedRoll = index),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<Map<String, String>>(
                    future: roll['chamber'] == 'House' ? _houseNames : null,
                    builder: (context, names) => _RollDetails(
                      key: ValueKey(selected),
                      roll: roll,
                      fullNames: roll['chamber'] == 'House'
                          ? names.data ?? const {}
                          : const {},
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BillMetadata extends StatelessWidget {
  const _BillMetadata({required this.metadata});
  final _Record metadata;

  @override
  Widget build(BuildContext context) {
    final actions = _records(metadata['actions']);
    final versions = _records(metadata['textVersions'] ?? []);
    final costEstimates = _records(metadata['costEstimates'] ?? []);
    final relatedBills = _records(metadata['relatedBills'] ?? []);
    final fields = <String, String>{
      'Introduced': metadata['introduced'] as String,
      'Latest action':
          "${metadata['latestActionDate']} ${metadata['latestAction']}".trim(),
      'Policy area': metadata['policyArea'] as String,
      'Committee reports': (metadata['committeeReports'] as List? ?? []).join(
        ', ',
      ),
      for (final key in [
        'sponsors',
        'cosponsors',
        'committees',
        'subjects',
        'laws',
      ])
        '${key[0].toUpperCase()}${key.substring(1)}': (metadata[key] as List)
            .where((value) => value != '')
            .join(', '),
    };
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Bill status and legislative history'),
      expandedAlignment: Alignment.centerLeft,
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final field in fields.entries)
          if (field.value.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('${field.key}  ${field.value}'),
            ),
        for (final version in versions)
          _SourceLink(
            label: "${version['stage']} · ${version['date']} (GovInfo XML)",
            url: version['url'] as String,
          ),
        for (final estimate in costEstimates)
          _SourceLink(
            label: "CBO estimate · ${estimate['title']}",
            url: estimate['url'] as String,
          ),
        for (final related in relatedBills)
          _SourceLink(
            label:
                "Related measure · ${related['title']} · ${related['relationship']}",
            url: related['url'] as String,
          ),
        for (final action in actions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${action['date']}  ${action['text']}'),
          ),
      ],
    );
  }
}

class _RollDetails extends StatefulWidget {
  const _RollDetails({super.key, required this.roll, required this.fullNames});
  final _Record roll;
  final Map<String, String> fullNames;

  String displayName(_Record row) =>
      fullNames[row['id']] ?? row['name'] as String;

  @override
  State<_RollDetails> createState() => _RollDetailsState();
}

class _RollDetailsState extends State<_RollDetails> {
  String? _position;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final roll = widget.roll;
    final counts = roll['counts'] as _Record;
    final rows =
        _records(roll['members']).where((row) {
          final terms =
              "${widget.displayName(row)} ${row['name']} ${row['state']} ${row['party']}"
                  .toLowerCase();
          return (_position == null || _position == row['position']) &&
              terms.contains(_query.trim().toLowerCase());
        }).toList()..sort(
          (a, b) => (a['name'] as String).compareTo(b['name'] as String),
        );
    final description = roll['description'] as String;
    final amendment = roll['amendment'] as String;
    final amendmentDetail = roll['amendmentDetail'] as String;
    final tieBreaker = roll['tieBreaker'] as String? ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          roll['question'] as String,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (description.isNotEmpty && description != roll['question'])
          Text(description),
        if (amendment.isNotEmpty)
          Text(
            'Amendment ${amendment.replaceFirst(RegExp(r'^S\.Amdt\.\s*'), '')}',
          ),
        if (amendmentDetail.isNotEmpty) Text(amendmentDetail),
        const SizedBox(height: 8),
        Text("Result  ${roll['result']}"),
        if (tieBreaker.isNotEmpty)
          Text('Vice-presidential tie-breaker  $tieBreaker'),
        _SourceLink(
          label: "Official ${roll['chamber']} roll call",
          url: roll['url'] as String,
        ),
        const SizedBox(height: 8),
        Semantics(
          label: _positions.entries
              .map((entry) => '${entry.value.$1} ${counts[entry.key]}')
              .join(', '),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  for (final entry in _positions.entries)
                    if ((counts[entry.key] as int) > 0)
                      Expanded(
                        flex: counts[entry.key] as int,
                        child: ColoredBox(color: entry.value.$2),
                      ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final entry in _positions.entries)
              FilterChip(
                avatar: Icon(Icons.circle, color: entry.value.$2, size: 12),
                label: Text('${entry.value.$1} ${counts[entry.key]}'),
                selected: _position == entry.key,
                onSelected: (selected) =>
                    setState(() => _position = selected ? entry.key : null),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          '“Not Voting” is the chamber’s recorded position. Reasons are unavailable in the roll-call record.',
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            labelText: 'Find a member by name or state code',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty) const Text('No members match these filters.'),
        for (final row in rows)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(widget.displayName(row)),
            subtitle: Text(
              [
                if (row['party'] != '') row['party'],
                if (row['state'] != '') row['state'],
                if (row['district'] != '') 'District ${row['district']}',
              ].join(' · '),
            ),
            trailing: Text(
              row['vote'] as String,
              style: TextStyle(
                color: _positions[row['position']]?.$2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _SourceLink extends StatelessWidget {
  const _SourceLink({required this.label, required this.url});
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () async {
        if (!await launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            ) &&
            context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open the official source.'),
            ),
          );
        }
      },
      child: Text(label),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
