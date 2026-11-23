import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/data_provider.dart';
import '../data/static/us_house_apportionment.dart';
import '../map/national_map_painter.dart';
import '../utils/search_handler.dart';
import 'president_detail_screen.dart';
import 'state_delegation_screen.dart';
import 'state_detail_screen.dart';
import 'supreme_court_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _navy = Color(0xFF102E50);
  static const _selectedBlue = Color(0xFF264A72);
  static const _pink = Color(0xFFE9A6B6);
  static const _outline = Color(0xFFD4DEEB);
  static const _muted = Color(0xFF4D637A);
  static const _quickStates = [
    'VT',
    'NH',
    'MA',
    'RI',
    'CT',
    'NJ',
    'DE',
    'MD',
    'DC',
  ];

  String? _pickedStateId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final data = context.read<MapDataProvider>();
      if (data.atlas == null && !data.isLoading) data.loadAllData();
    });
  }

  String _name(String id) => SearchHandler.stateCodeToName[id] ?? id;

  void _selectState(String id) {
    if (_pickedStateId == id) {
      _openState(id);
    } else {
      setState(() => _pickedStateId = id);
    }
  }

  void _openState(String id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => StateDetailScreen(stateId: id)),
    );
  }

  void _openDelegation(String id, DelegationChamber chamber) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StateDelegationScreen(stateId: id, chamber: chamber),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MapDataProvider>();
    final atlas = provider.atlas;
    final pathCache = provider.pathCache;
    final stateIds = (atlas?.states.map((state) => state.id).toList() ?? [])
      ..sort((a, b) => _name(a).compareTo(_name(b)));

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('USA Representative Map'),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: ColoredBox(
            color: _pink,
            child: SizedBox(height: 3, width: double.infinity),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: Image.asset('assets/img/logo.png', width: 28, height: 28),
          ),
        ],
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (atlas == null || pathCache == null || stateIds.isEmpty) {
              return const Center(child: Text('Failed to load map data.'));
            }
            final picked = _pickedStateId;
            final selected = stateIds.contains(picked)
                ? picked!
                : stateIds.contains('CA')
                ? 'CA'
                : stateIds.first;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Explore states',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: _navy,
                          ),
                        ),
                        Semantics(
                          label: 'Choose a state or D.C.',
                          child: SizedBox(
                            width: 176,
                            child: DropdownButton<String>(
                              key: const Key('national-state-picker'),
                              isExpanded: true,
                              value: selected,
                              items: [
                                for (final id in stateIds)
                                  DropdownMenuItem(
                                    value: id,
                                    child: Text(
                                      _name(id),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (id) {
                                if (id != null) _selectState(id);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    NationalMap(
                      key: const Key('interactive-national-map'),
                      atlas: atlas,
                      pathCache: pathCache,
                      selectedStateId: selected,
                      onStateSelected: _selectState,
                    ),
                    if (_quickStates.any(stateIds.contains)) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Northeast & D.C.',
                        style: TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          for (final id in _quickStates)
                            if (stateIds.contains(id))
                              OutlinedButton(
                                key: ValueKey('national-state-$id'),
                                onPressed: () => _selectState(id),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(44, 44),
                                  padding: EdgeInsets.zero,
                                  backgroundColor: selected == id
                                      ? _selectedBlue
                                      : Colors.white,
                                  foregroundColor: selected == id
                                      ? Colors.white
                                      : _navy,
                                  side: const BorderSide(color: _outline),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Tooltip(
                                  message: _name(id),
                                  child: Text(id),
                                ),
                              ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    _delegationCard(selected),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PresidentDetailScreen(),
                            ),
                          ),
                          child: const Text('The President'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SupremeCourtScreen(),
                            ),
                          ),
                          child: const Text('Supreme Court'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _delegationCard(String id) {
    final isDc = id == 'DC';
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            key: const Key('selected-state-name'),
            onTap: () => _openState(id),
            leading: DecoratedBox(
              decoration: BoxDecoration(
                color: _navy,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SizedBox.square(
                dimension: 42,
                child: Center(
                  child: Text(
                    id,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            title: Text(
              _name(id),
              style: const TextStyle(
                color: _navy,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: const Text(
              'Congressional delegation',
              style: TextStyle(color: _muted),
            ),
            trailing: const Icon(Icons.chevron_right, color: _selectedBlue),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16, color: _outline),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _seatButton(
                    id,
                    DelegationChamber.senate,
                    isDc ? 0 : 2,
                    'U.S. Senate seats',
                  ),
                ),
                Expanded(
                  child: _seatButton(
                    id,
                    DelegationChamber.house,
                    isDc ? 1 : usHouseApportionment[id],
                    isDc ? 'Nonvoting House delegate' : 'U.S. House seats',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _seatButton(
    String id,
    DelegationChamber chamber,
    int? count,
    String label,
  ) {
    return TextButton(
      key: ValueKey('national-seats-${chamber.name}'),
      onPressed: () => _openDelegation(id, chamber),
      style: TextButton.styleFrom(
        alignment: AlignmentDirectional.centerStart,
        foregroundColor: _selectedBlue,
        minimumSize: const Size(0, 54),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count?.toString() ?? '—',
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
          ),
          Text(label),
        ],
      ),
    );
  }
}
