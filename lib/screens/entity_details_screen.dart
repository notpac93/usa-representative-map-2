import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../design/civic_palette.dart';

/// Shared destination for geographic and public-office profiles. Facts belong
/// to the entity; statewide series are always explicitly labeled as context.
class EntityDetailsButton extends StatelessWidget {
  final String name;
  final String category;
  final String? stateId;
  final Map<String, String> facts;
  final bool isLeader;
  final bool isState;
  final String? website;

  const EntityDetailsButton({
    super.key,
    required this.name,
    required this.category,
    this.stateId,
    this.facts = const {},
    this.isLeader = false,
    this.isState = false,
    this.website,
  });

  @override
  Widget build(BuildContext context) => TextButton.icon(
    style: TextButton.styleFrom(
      foregroundColor: IconTheme.of(context).color ?? CivicPalette.actionBlue,
    ),
    icon: const Icon(Icons.insights_outlined, size: 19),
    label: const Text('Details'),
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EntityDetailsScreen(
          name: name,
          category: category,
          stateId: stateId,
          facts: facts,
          isLeader: isLeader,
          isState: isState,
          website: website,
        ),
      ),
    ),
  );
}

class EntityDetailsScreen extends StatefulWidget {
  final String name;
  final String category;
  final String? stateId;
  final Map<String, String> facts;
  final bool isLeader;
  final bool isState;
  final String? website;

  const EntityDetailsScreen({
    super.key,
    required this.name,
    required this.category,
    this.stateId,
    this.facts = const {},
    this.isLeader = false,
    this.isState = false,
    this.website,
  });

  @override
  State<EntityDetailsScreen> createState() => _EntityDetailsScreenState();
}

class _EntityDetailsScreenState extends State<EntityDetailsScreen> {
  late final Future<Map<String, dynamic>> _population = _loadPopulation();
  String _metric = 'Population';
  String _period = '5 years';

  Future<Map<String, dynamic>> _loadPopulation() async =>
      jsonDecode(
            await rootBundle.loadString('assets/data/detail_population.json'),
          )
          as Map<String, dynamic>;

  Future<void> _open(String url) async {
    try {
      if (await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      /* Report a recoverable failure in the current screen. */
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open this source. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      backgroundColor: CivicPalette.canvas,
      appBar: AppBar(
        title: const Text('Details'),
        backgroundColor: CivicPalette.surface,
        foregroundColor: CivicPalette.ink,
        bottom: const TabBar(
          labelColor: CivicPalette.actionBlue,
          unselectedLabelColor: CivicPalette.mutedInk,
          tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Trends'),
            Tab(text: 'Sources'),
          ],
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _population,
        builder: (context, snapshot) {
          final raw =
              snapshot.data?['states']?[widget.stateId]
                  as Map<String, dynamic>?;
          final series =
              raw?.map(
                (year, value) =>
                    MapEntry(int.parse(year), (value as num).toDouble()),
              ) ??
              <int, double>{};
          return TabBarView(
            children: [
              _page(_overview(series)),
              _page(
                _trends(
                  series,
                  snapshot.connectionState == ConnectionState.waiting,
                ),
              ),
              _page(_sources(snapshot.data)),
            ],
          );
        },
      ),
    ),
  );

  Widget _page(List<Widget> children) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.category.toUpperCase(),
              style: const TextStyle(
                color: CivicPalette.teal,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.name,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: CivicPalette.ink,
              ),
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    ),
  );

  Widget _card(String title, String subtitle, Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: CivicPalette.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: CivicPalette.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: CivicPalette.ink,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(color: CivicPalette.mutedInk, height: 1.5),
        ),
        const SizedBox(height: 18),
        child,
      ],
    ),
  );

  List<Widget> _overview(Map<int, double> series) => [
    _card(
      widget.isLeader ? 'Office at a glance' : 'At a glance',
      'Key facts from the records included in this app.',
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _stat('Profile', widget.category),
          if (widget.stateId != null)
            _stat('State / jurisdiction', widget.stateId!),
          for (final fact in widget.facts.entries)
            if (fact.value.trim().isNotEmpty) _stat(fact.key, fact.value),
        ],
      ),
    ),
    if (widget.isState && series.isNotEmpty)
      _card(
        'Population snapshot',
        'July 1 estimate • Census Vintage 2024 • historical data',
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _stat(
              'Residents · 2024',
              NumberFormat.decimalPattern().format(series[2024]),
            ),
            _stat(
              'Change · 2020–2024',
              '${((series[2024]! / series[2020]! - 1) * 100).toStringAsFixed(1)}%',
            ),
          ],
        ),
      ),
    _card(
      'Explore the profile',
      'Choose a section above to keep the page focused.',
      Column(
        children: [
          _navigation(
            Icons.show_chart,
            'Trends',
            widget.isLeader
                ? 'State context and changes over time'
                : 'Population and economic indicators',
            1,
          ),
          _navigation(
            Icons.fact_check_outlined,
            'Sources',
            'Coverage, dates, and official data links',
            2,
          ),
        ],
      ),
    ),
  ];

  Widget _stat(String label, String value) => SizedBox(
    width: 230,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CivicPalette.canvas,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: CivicPalette.mutedInk, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: CivicPalette.ink,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _navigation(IconData icon, String title, String subtitle, int tab) =>
      Builder(
        builder: (context) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: CivicPalette.actionBlue),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => DefaultTabController.of(context).animateTo(tab),
        ),
      );

  List<Widget> _trends(Map<int, double> series, bool loading) {
    final years =
        series.keys.where((y) => _period == '5 years' || y >= 2022).toList()
          ..sort();
    final economic = _metric == 'GDP';
    return [
      if (!widget.isState && widget.stateId == null)
        _card(
          'National context',
          'National population and economic series are not connected yet.',
          const Text('Geography: United States'),
        ),
      if (!widget.isState && widget.stateId != null)
        _card(
          'State context${widget.stateId == null ? '' : ' · ${widget.stateId}'}',
          widget.isLeader
              ? 'These indicators describe the state, not an individual leader’s performance or the effects of their policies.'
              : 'These indicators describe the whole state. City and county time series are not connected yet.',
          const Text(
            'Geography: state level',
            style: TextStyle(
              color: CivicPalette.teal,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      _card(
        'People & economy',
        'One indicator at a time, with its period and source visible.',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final metric in [
                  'Population',
                  'GDP',
                  'Income',
                  'Employment',
                ])
                  ChoiceChip(
                    label: Text(metric),
                    selected: _metric == metric,
                    onSelected: (_) => setState(() => _metric = metric),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (_metric == 'Population' && loading)
              const LinearProgressIndicator()
            else if (_metric == 'Population' && years.length >= 2) ...[
              Wrap(
                spacing: 8,
                children: [
                  for (final period in ['3 years', '5 years'])
                    ChoiceChip(
                      label: Text(period),
                      selected: _period == period,
                      onSelected: (_) => setState(() => _period = period),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Population · ${years.first}–${years.last}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              Text(
                '${NumberFormat.decimalPattern().format(series[years.last])} residents in ${years.last}',
              ),
              const SizedBox(height: 20),
              for (final year in years)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$year'),
                          Text(
                            NumberFormat.decimalPattern().format(series[year]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Semantics(
                        label: '$year: ${series[year]!.round()} residents',
                        child: LinearProgressIndicator(
                          value:
                              series[year]! /
                              (series.values.reduce((a, b) => a > b ? a : b) *
                                  1.05),
                          minHeight: 8,
                          color: CivicPalette.teal,
                          backgroundColor: CivicPalette.tealTint,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                'Change over selected period: ${((series[years.last]! / series[years.first]! - 1) * 100).toStringAsFixed(1)}%',
              ),
              const SizedBox(height: 12),
              const Text(
                'Census Bureau • Vintage 2024 • July 1 estimates\nBar scale begins at zero. Historical snapshot, not live data.',
                style: TextStyle(fontSize: 12, color: CivicPalette.mutedInk),
              ),
            ] else ...[
              Icon(
                economic ? Icons.account_balance_outlined : Icons.query_stats,
                color: CivicPalette.subtleInk,
                size: 32,
              ),
              const SizedBox(height: 10),
              Text(
                '$_metric data not connected',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 8),
              Text(switch (_metric) {
                'GDP' =>
                  'Planned: annual GDP, inflation-adjusted growth, and GDP per resident. Dollar values and real growth will be labeled separately.',
                'Income' =>
                  'Planned: median household income and changes over time, with the survey period shown.',
                'Employment' =>
                  'Planned: unemployment rates and employment changes, with monthly or annual periods shown.',
                _ =>
                  'No state population history is available for this jurisdiction in the bundled dataset.',
              }),
              const SizedBox(height: 8),
              const Text(
                'No estimated or sample values are displayed.',
                style: TextStyle(color: CivicPalette.mutedInk, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  List<Widget> _sources(Map<String, dynamic>? data) => [
    _card(
      'Data coverage',
      'Dates and geography matter when comparing records.',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile facts come from the app’s bundled civic records. Their last verification date is not supplied here; confirm office and contact details with the official office.',
          ),
          const SizedBox(height: 12),
          Text('Population: ${data?['description'] ?? 'Dataset unavailable.'}'),
          if (data != null) ...[
            const SizedBox(height: 8),
            Text(
              'Retrieved: ${data['retrievedAt'].toString().split('T').first} • ${data['vintage']}',
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'GDP, income, employment, city history, and county history are not yet connected.',
          ),
        ],
      ),
    ),
    _card(
      'Official sources',
      'Population is bundled for offline use. Other links are reference sources for future indicators.',
      Column(
        children: [
          if (widget.website != null)
            _source('Profile website', widget.website!),
          if (data != null)
            _source(
              'Census population dataset · Vintage 2024',
              data['url'] as String,
            ),
          _source(
            'Census · Population estimates',
            'https://www.census.gov/programs-surveys/popest.html',
          ),
          _source(
            'BEA · GDP by state',
            'https://www.bea.gov/data/gdp/gdp-state',
          ),
          _source(
            'Census · Household income',
            'https://www.census.gov/programs-surveys/acs',
          ),
          _source(
            'BLS · Local employment statistics',
            'https://www.bls.gov/lau/',
          ),
        ],
      ),
    ),
  ];

  Widget _source(String label, String url) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: const Icon(Icons.open_in_new, size: 18),
    onTap: () => _open(url),
  );
}
