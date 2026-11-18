import '../widgets/indicator_history_chart.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/models.dart';
import '../data/static/capitals.dart';

/// Approved compact state/governor design. No sample activity or economic
/// numbers enter the app: missing connections have explicit coverage states.
class CivicProfileScreen extends StatefulWidget {
  final String stateId;
  final String stateName;
  final String initialTab;
  final Governor? governor;
  final bool governorProfile;
  final VoidCallback? onExploreMap;
  final VoidCallback? onState;
  final VoidCallback? onVotingRules;
  final List<Widget> governmentEntries;

  const CivicProfileScreen({
    super.key,
    required this.stateId,
    required this.stateName,
    this.initialTab = 'Overview',
    this.governor,
    this.governorProfile = false,
    this.onExploreMap,
    this.onState,
    this.onVotingRules,
    this.governmentEntries = const [],
  });

  @override
  State<CivicProfileScreen> createState() => _CivicProfileScreenState();
}

class _CivicProfileScreenState extends State<CivicProfileScreen> {
  late final Future<Map<String, dynamic>> _data = _load();
  final _scroll = ScrollController();
  late String _tab = _tabs.contains(widget.initialTab)
      ? widget.initialTab
      : 'Overview';
  String _economicChart = 'gdp';
  String _housingChart = 'rent';
  String _activity = 'All';
  bool get _leader => widget.governorProfile;
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _paper => _dark ? const Color(0xFF18212C) : Colors.white;
  Color get _ink => _dark ? const Color(0xFFF1F4F8) : const Color(0xFF15191E);
  Color get _muted => _dark ? const Color(0xFFAFBDCC) : const Color(0xFF626D79);
  Color get _border =>
      _dark ? const Color(0xFF354252) : const Color(0xFFE9ECF0);
  Color get _soft => _dark ? const Color(0xFF23303F) : const Color(0xFFF5F6F7);
  Color get _green => _dark ? const Color(0xFF73D5AC) : const Color(0xFF23845F);
  Color get _red => _dark ? const Color(0xFFFF8599) : const Color(0xFFD13752);
  static const _yellow = Color(0xFFEFC62E);
  List<String> get _tabs => _leader
      ? [
          'Overview',
          'Office',
          'History',
          'Activity',
          'State',
          'Contact',
          'Sources',
        ]
      : [
          'Overview',
          'Population',
          'Economy',
          'Housing',
          'Government',
          'History',
          'Sources',
        ];

  Map<String, dynamic> _indicators = {};
  String? _indicatorError;
  Map<String, dynamic> _governorHistory = {};

  Future<Map<String, dynamic>> _load() async {
    final files = await Future.wait([
      DefaultAssetBundle.of(
        context,
      ).loadString('assets/data/detail_population.json'),
      DefaultAssetBundle.of(context)
          .loadString('assets/data/government_indicators.json')
          .catchError((_) => '{}'),
      DefaultAssetBundle.of(
        context,
      ).loadString('assets/data/governor_history.json').catchError((_) => '{}'),
    ]);
    final data = jsonDecode(files[0]) as Map<String, dynamic>;
    try {
      data['governorHistory'] = jsonDecode(files[2]);
    } catch (_) {
      data['governorHistory'] = <String, dynamic>{};
    }
    try {
      data['indicators'] = jsonDecode(files[1]);
      if ((data['indicators'] as Map).isEmpty) {
        data['indicatorError'] = 'Government indicators could not load.';
      }
    } catch (_) {
      data['indicatorError'] =
          'Government indicators could not load. Try reopening this profile.';
    }
    return data;
  }

  Map<String, dynamic>? _metric(String name) =>
      _indicators['states']?[widget.stateId]?[name] as Map<String, dynamic>?;

  String _value(String name) {
    final metric = _metric(name);
    if (metric == null) return 'Unavailable';
    final value = (metric['value'] as num).toDouble();
    if (metric['unit'] == 'USD') {
      return name == 'gdp'
          ? NumberFormat.compactCurrency(
              symbol: '\$',
              decimalDigits: 2,
            ).format(value)
          : NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(value);
    }
    return '${name == 'realGdpGrowth' && value > 0 ? '+' : ''}${value.toStringAsFixed(1)}%';
  }

  String _periodLabel(String name) =>
      _metric(name)?['period'] as String? ?? 'No record';

  Widget _metricRecord(String label, String name) {
    final metric = _metric(name);
    if (metric == null) {
      return _row(label, 'Not available for this jurisdiction');
    }
    final source =
        _indicators['sources'][metric['source']] as Map<String, dynamic>;
    final moe = metric['marginOfError'] as num?;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(color: _ink, fontSize: 12)),
      subtitle: Text(
        '${_value(name)} · ${metric['period']}',
        style: TextStyle(color: _muted, fontSize: 11),
      ),
      children: [
        if (moe != null)
          _row(
            '90% margin of error',
            '±${NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(moe)}',
          ),
        if (name == 'homeownership')
          _notice(
            'Calculated from owner-occupied / occupied housing units in ACS table B25003. A margin of error for this derived rate is not calculated.',
          ),
        if (name == 'unemployment')
          _notice(
            'Seasonally adjusted monthly rate. ${(metric['footnotes'] as List).join(' ')}',
          ),
        _row('Reporting period', metric['period'] as String),
        _row(
          'Retrieved (UTC)',
          source['retrievedAt'].toString().split('T').first,
        ),
        _row(
          source['agency'] as String,
          'Open .gov source',
          () => _open(
            (source['urls'] as List).cast<String>().firstWhere(
              (url) =>
                  metric['table'] == null ||
                  url.contains(
                    '-${metric['table'].toString().toLowerCase()}.dat',
                  ),
              orElse: () => (source['urls'] as List).first as String,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _select(String tab) {
    setState(() => _tab = tab);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && ['https', 'http', 'tel'].contains(uri.scheme)) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
      } catch (_) {
        /* Keep the profile available if a source cannot open. */
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open this office link. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _paper,
    appBar: AppBar(
      backgroundColor: _paper,
      foregroundColor: _ink,
      elevation: 0,
      title: const Text(
        'USA Representative Map',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      actions: [
        if (widget.onExploreMap != null)
          IconButton(
            key: const Key('profile_map_button'),
            tooltip: 'Explore state map',
            onPressed: widget.onExploreMap,
            icon: const Icon(Icons.map_outlined),
          ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _identity(),
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: _border)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: _tabs
                      .map(
                        (tab) => Semantics(
                          selected: _tab == tab,
                          child: TextButton(
                            key: ValueKey('profile_tab_$tab'),
                            onPressed: () => _select(tab),
                            style: TextButton.styleFrom(
                              foregroundColor: _tab == tab ? _ink : _muted,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 8,
                              ),
                              shape: const RoundedRectangleBorder(),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  tab,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _tab == tab
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: 17,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: _tab == tab
                                        ? _yellow
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _data,
                builder: (context, snapshot) {
                  _indicators =
                      snapshot.data?['indicators'] as Map<String, dynamic>? ??
                      {};
                  _indicatorError = snapshot.data?['indicatorError'] as String?;
                  _governorHistory =
                      snapshot.data?['governorHistory']
                          as Map<String, dynamic>? ??
                      {};
                  final raw =
                      snapshot.data?['states']?[widget.stateId]
                          as Map<String, dynamic>?;
                  final population =
                      raw?.map(
                        (year, value) => MapEntry(
                          int.parse(year),
                          (value as num).toDouble(),
                        ),
                      ) ??
                      <int, double>{};
                  final years = population.keys.toList()..sort();
                  return ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                    children: [
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const LinearProgressIndicator(),
                      if (snapshot.hasError)
                        _notice(
                          'Population data could not load. Office records and navigation remain available.',
                        ),
                      ...switch (_tab) {
                        'Overview' => _overview(population, years),
                        'Population' => _population(population, years),
                        'Economy' => _economy(),
                        'Housing' => _housing(),
                        'Government' => _government(),
                        'Office' => _office(),
                        'History' => _pastGovernors(),
                        'Activity' => _activities(),
                        'State' => [
                          _context(),
                          ..._population(population, years),
                          ..._economy(),
                          ..._housing(),
                          if (widget.onState != null)
                            _row(
                              'Open state profile',
                              widget.stateName,
                              widget.onState,
                            ),
                        ],
                        'Contact' => _contact(),
                        _ => _sources(snapshot.data),
                      },
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _identity() {
    final g = widget.governor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 9, 20, 17),
      child: Row(
        children: [
          if (_leader) ...[
            ClipOval(
              child: g?.photoLocalPath != null
                  ? Image.asset(
                      'assets/img/${g!.photoLocalPath}',
                      width: 55,
                      height: 55,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _avatar(),
                    )
                  : _avatar(),
            ),
            const SizedBox(width: 13),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_leader ? 'GOVERNOR' : 'STATE'} / ${widget.stateId}',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _leader ? g?.name ?? 'Governor' : widget.stateName,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_leader)
                  Text(
                    [
                      if (g?.party != null) g!.party!,
                      widget.stateName,
                    ].join(' · '),
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar() => Container(
    width: 55,
    height: 55,
    color: _soft,
    child: Icon(Icons.person_outline, color: _muted, size: 28),
  );

  Widget _heading(String title, [String note = '']) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (note.isNotEmpty)
          Flexible(
            child: Text(
              note,
              textAlign: TextAlign.right,
              style: TextStyle(color: _muted, fontSize: 10),
            ),
          ),
      ],
    ),
  );

  Widget _panel(List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 17),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: _paper,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  Widget _notice(String text) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: _soft,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(color: _muted, fontSize: 11, height: 1.5),
    ),
  );

  Widget _row(String title, String detail, [VoidCallback? action]) => InkWell(
    onTap: action,
    borderRadius: BorderRadius.circular(6),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: TextStyle(color: _ink, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              detail,
              textAlign: TextAlign.right,
              style: TextStyle(color: _muted, fontSize: 11),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 7),
            Icon(Icons.chevron_right, size: 15, color: _muted),
          ],
        ],
      ),
    ),
  );

  Widget _stats(List<(String, String, String, Color?)> stats) => Padding(
    padding: const EdgeInsets.only(bottom: 17),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 9),
              decoration: BoxDecoration(
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stats[i].$1,
                    style: TextStyle(fontSize: 10, color: _muted),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    stats[i].$2,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stats[i].$3,
                    style: TextStyle(
                      fontSize: 10,
                      color: stats[i].$4 ?? _muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );

  String _compact(double value) =>
      NumberFormat.compact(locale: 'en_US').format(value);
  String _percent(double from, double to) {
    final value = (to / from - 1) * 100;
    return '${value > 0 ? '+' : ''}${value.toStringAsFixed(2)}%';
  }

  Color _changeColor(double from, double to) => to >= from ? _green : _red;

  List<Widget> _overview(Map<int, double> pop, List<int> years) => [
    _heading(_leader ? 'Office highlights' : 'Quick look', 'Explore'),
    if (_leader) ...[
      _row(
        'Office & responsibilities',
        'Governor · ${widget.stateId}',
        () => _select('Office'),
      ),
      _row(
        'Official activity',
        'Orders, legislation & budget',
        () => _select('Activity'),
      ),
      _row('Office contacts', 'Phone & website', () => _select('Contact')),
    ] else ...[
      _row(
        'Population history',
        years.isEmpty ? 'No series available' : '${years.first}–${years.last}',
        () => _select('Population'),
      ),
      _row(
        'State economy',
        'GDP, income & employment',
        () => _select('Economy'),
      ),
      _row('Housing', 'Rent, values & ownership', () => _select('Housing')),
      _row(
        'Government & leaders',
        'Governor & delegation',
        () => _select('Government'),
      ),
    ],
    _row('Sources & coverage', 'Records & dates', () => _select('Sources')),
    const SizedBox(height: 16),
    if (_leader) ...[
      _heading('Office at a glance'),
      _stats([
        ('Office', 'Governor', widget.stateName, null),
        (
          'Recorded terms',
          '${widget.governor?.terms.length ?? 0}',
          'See office record',
          null,
        ),
        ('Jurisdiction', widget.stateId, 'Statewide', null),
      ]),
      _panel([
        _heading('Official activity', 'Coverage'),
        _row('Executive orders', 'Not connected', () => _select('Activity')),
        _row(
          'Signed & vetoed legislation',
          'Not connected',
          () => _select('Activity'),
        ),
        _angledActions(
          'Office contact',
          () => _select('Contact'),
          'State profile',
          () => _select('State'),
        ),
      ]),
      _heading('State context', 'Historical population'),
      _context(),
    ] else if (years.length >= 2) ...[
      _changePanel(pop, years),
      _heading('State overall', 'Census estimates'),
    ],
    if (years.length >= 2) ...[
      _populationStats(pop, years),
      _trendRows(pop, years),
    ] else
      _notice(
        'Population history is not available for this jurisdiction in the bundled dataset.',
      ),
    if (!_leader && widget.onExploreMap != null)
      _row(
        'Explore state map',
        'Cities, counties & map layers',
        widget.onExploreMap,
      ),
  ];

  Widget _angledActions(
    String first,
    VoidCallback onFirst,
    String second,
    VoidCallback onSecond, {
    Color? firstColor,
    Color? secondColor,
  }) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      children: [
        Expanded(
          child: ClipPath(
            clipper: const _SlantedClipper(),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    firstColor ??
                    (_dark ? const Color(0xFFC7D8EE) : const Color(0xFF15283F)),
                foregroundColor: _dark ? const Color(0xFF142132) : Colors.white,
                shape: const RoundedRectangleBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: onFirst,
              child: Text(
                first,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: ClipPath(
            clipper: const _SlantedClipper(),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: secondColor ?? _soft,
                foregroundColor: secondColor == null
                    ? _ink
                    : (_dark ? const Color(0xFF142132) : Colors.white),
                shape: const RoundedRectangleBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: onSecond,
              child: Text(
                second,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _changePanel(Map<int, double> pop, List<int> years) {
    final first = pop[years.first]!,
        last = pop[years.last]!,
        previous = pop[years[years.length - 2]]!;
    return _panel([
      Text(
        'How has ${widget.stateName}’s population changed?',
        style: TextStyle(color: _ink, fontSize: 12),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: Text(
              '${years.first}–${years.last}  ${_percent(first, last)}',
              style: TextStyle(fontSize: 11, color: _changeColor(first, last)),
            ),
          ),
          Expanded(
            child: Text(
              'Latest year  ${_percent(previous, last)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                color: _changeColor(previous, last),
              ),
            ),
          ),
        ],
      ),
      _angledActions(
        'Long-term change',
        () => _select('Population'),
        'Annual change',
        () => _select('Population'),
        firstColor: _changeColor(first, last),
        secondColor: _changeColor(previous, last),
      ),
      const SizedBox(height: 7),
      Text(
        'July 1 estimates · ${years.last}',
        style: TextStyle(fontSize: 10, color: _muted),
      ),
    ]);
  }

  Widget _populationStats(Map<int, double> pop, List<int> years) {
    final last = pop[years.last]!,
        first = pop[years.first]!,
        previous = pop[years[years.length - 2]]!;
    return _stats([
      (
        'Population · ${years.last}',
        _compact(last),
        '${_percent(first, last)} since ${years.first}',
        _changeColor(first, last),
      ),
      (
        'Annual change',
        _percent(previous, last),
        '${years[years.length - 2]}–${years.last}',
        _changeColor(previous, last),
      ),
      ('State GDP', _value('gdp'), 'BEA · ${_periodLabel('gdp')}', null),
    ]);
  }

  Widget _trendRows(Map<int, double> pop, List<int> years) {
    final change = _changeColor(pop[years.first]!, pop[years.last]!);
    return _panel([
      Row(
        children: [
          Expanded(
            child: Text(
              'Indicator',
              style: TextStyle(fontSize: 10, color: _muted),
            ),
          ),
          Expanded(
            child: Text(
              'Trend · ${years.first}–${years.last}',
              style: TextStyle(fontSize: 10, color: _muted),
            ),
          ),
          Expanded(
            child: Text(
              'Latest / change',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 10, color: _muted),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Divider(height: 1, color: _border),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Population',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
            ),
            Expanded(
              child: Semantics(
                label: 'Population trend ${years.first} to ${years.last}',
                child: SizedBox(
                  height: 30,
                  child: CustomPaint(
                    painter: _Sparkline(
                      years.map((y) => pop[y]!).toList(),
                      change,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _compact(pop[years.last]!),
                    style: TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    _percent(pop[years.first]!, pop[years.last]!),
                    style: TextStyle(color: change, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      _row('State GDP', '${_value('gdp')} · ${_periodLabel('gdp')}'),
      _row(
        'Household income',
        '${_value('income')} · ${_periodLabel('income')}',
      ),
    ]);
  }

  Widget _context() => _notice(
    '${widget.stateName} indicators describe the state, not an individual leader’s performance or the effects of their policies.',
  );

  List<Widget> _population(Map<int, double> pop, List<int> allYears) => [
    _heading('Population', '${widget.stateName} · residents'),
    if (allYears.length >= 2) _populationStats(pop, allYears),
    IndicatorHistoryChart(
      key: const ValueKey('population_history'),
      title: 'Population history',
      unit: 'residents',
      source: 'Census · Vintage 2024',
      population: true,
      note:
          'July 1 estimates · Historical population snapshot. Colors indicate numeric direction, not a policy judgment.',
      points: allYears.map((y) => HistoryPoint('$y', pop[y]!)).toList(),
      onSource: () => _select('Sources'),
    ),
  ];

  Widget _history(String metric) {
    final record = _metric(metric);
    final raw = record?['history'] as Map<String, dynamic>? ?? {};
    final margins =
        record?['historyMarginsOfError'] as Map<String, dynamic>? ?? {};
    final titles = {
      'gdp': 'GDP history',
      'income': 'Income history',
      'unemployment': 'Unemployment history',
      'rent': 'Rent history',
      'homeValue': 'Home value history',
      'homeownership': 'Homeownership history',
    };
    final survey = [
      'income',
      'rent',
      'homeValue',
      'homeownership',
    ].contains(metric);
    return IndicatorHistoryChart(
      key: ValueKey('history_$metric'),
      title: titles[metric]!,
      unit: record?['unit'] as String? ?? 'USD',
      survey: survey,
      source: survey
          ? 'Census ACS · Annual 1-year estimates'
          : metric == 'gdp'
          ? 'BEA · Annual current-dollar GDP'
          : 'BLS · Monthly, seasonally adjusted',
      note: survey
          ? 'Dollar amounts use each year’s dollars, not inflation-adjusted growth. Survey changes have not been tested for statistical significance. Homeownership changes are percentage points; no derived margin of error is calculated.'
          : metric == 'gdp'
          ? 'Nominal GDP in current dollars; this is not inflation-adjusted growth. BEA may revise earlier values.'
          : 'Changes are percentage points. Missing months are not interpolated. Latest observations may be preliminary. Colors indicate numeric direction.',
      points: raw.entries
          .map(
            (e) => HistoryPoint(
              e.key,
              (e.value as num).toDouble(),
              marginOfError: (margins[e.key] as num?)?.toDouble(),
            ),
          )
          .toList(),
      onSource: () => _select('Sources'),
    );
  }

  List<Widget> _economy() => [
    _heading('Economy', 'Verified .gov sources'),
    if (_indicatorError != null) _notice(_indicatorError!),
    _stats([
      ('Recorded GDP', _value('gdp'), 'BEA · ${_periodLabel('gdp')}', null),
      (
        'Median income',
        _value('income'),
        'ACS 1-year · ${_periodLabel('income')}',
        null,
      ),
      (
        'Unemployment',
        _value('unemployment'),
        'BLS · ${_periodLabel('unemployment')}',
        null,
      ),
    ]),
    Wrap(
      spacing: 7,
      runSpacing: 5,
      children: [
        for (final item in {
          'gdp': 'GDP',
          'income': 'Income',
          'unemployment': 'Unemployment',
        }.entries)
          ChoiceChip(
            key: ValueKey('chart_selector_${item.key}'),
            label: Text(item.value, style: const TextStyle(fontSize: 11)),
            selected: _economicChart == item.key,
            onSelected: (_) => setState(() => _economicChart = item.key),
          ),
      ],
    ),
    const SizedBox(height: 12),
    _history(_economicChart),
    _panel([
      _metricRecord('Current-dollar GDP', 'gdp'),
      _metricRecord('Inflation-adjusted GDP growth', 'realGdpGrowth'),
      _metricRecord('Median household income', 'income'),
      _metricRecord('Unemployment rate', 'unemployment'),
    ]),
    _notice(
      'GDP and income are annual figures; unemployment is monthly and seasonally adjusted. Reporting periods can differ. Expand a record for its .gov source and retrieval date.',
    ),
  ];

  List<Widget> _housing() => [
    _heading('Housing', 'Census ACS 1-year · ${_periodLabel('rent')}'),
    _stats([
      (
        'Median gross rent',
        _value('rent'),
        'Monthly · ${_periodLabel('rent')}',
        null,
      ),
      ('Home value', _value('homeValue'), 'Owner-occupied', null),
      ('Homeownership', _value('homeownership'), 'Occupied units', null),
    ]),
    Wrap(
      spacing: 7,
      runSpacing: 5,
      children: [
        for (final item in {
          'rent': 'Rent',
          'homeValue': 'Home value',
          'homeownership': 'Ownership',
        }.entries)
          ChoiceChip(
            key: ValueKey('chart_selector_${item.key}'),
            label: Text(item.value, style: const TextStyle(fontSize: 11)),
            selected: _housingChart == item.key,
            onSelected: (_) => setState(() => _housingChart = item.key),
          ),
      ],
    ),
    const SizedBox(height: 12),
    _history(_housingChart),
    _panel([
      _metricRecord('Median gross rent', 'rent'),
      _metricRecord('Median owner-occupied home value', 'homeValue'),
      _metricRecord('Homeownership rate', 'homeownership'),
    ]),
    _notice(
      'Income, rent, and home values use the ACS reporting year’s dollars. These are survey estimates, not current listings or sale prices. Expand a median for its margin of error.',
    ),
  ];

  List<Widget> _leadershipRules() => [
    _panel([
      _heading('How representation works'),
      Text(
        'State officials govern the state; U.S. senators and representatives serve in Congress. A statewide directory includes officials from many districts, not only the people who represent your home address.',
        style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
      ),
      if (widget.stateId == 'CA') ...[
        _row('Governor', 'Four-year term · maximum two terms'),
        _row('State Senate', '40 members · four-year terms'),
        _row('State Assembly', '80 members · two-year terms'),
        _notice(
          'Members first elected to the California Legislature on or after passage of Proposition 28 may serve up to 12 years combined in the Assembly and Senate. Earlier entrants are subject to different limits.',
        ),
        _row(
          'California leadership rules',
          'Official Assembly explanation',
          () => _open(
            'https://clerk.assembly.ca.gov/legislative-information/elected-officials',
          ),
        ),
        _row(
          'Governor term rules',
          'Official state roster',
          () => _open(
            'https://admin.cdn.sos.ca.gov/ca-roster/2026/complete-roster.pdf',
          ),
        ),
        _row('Rules checked', 'November 18, 2026'),
      ] else
        _notice(
          'Terms, term limits, selection methods, and legislative structure vary by state. State-specific rules have not yet been added here.',
        ),
    ]),
    if (widget.stateId == 'CA')
      _panel([
        _heading('More California leadership'),
        _notice(
          'The app does not yet include a complete roster of statewide officers, state legislators, judges, or local officials. Use these official directories for the remaining offices.',
        ),
        _row(
          'All statewide offices',
          'Secretary of State roster',
          () => _open(
            'https://admin.cdn.sos.ca.gov/ca-roster/2026/complete-roster.pdf',
          ),
        ),
        _row(
          'State senators',
          'Official Senate directory',
          () => _open('https://www.senate.ca.gov/senators'),
        ),
        _row(
          'Assembly members',
          'Official Assembly directory',
          () => _open('https://www.assembly.ca.gov/assemblymembers'),
        ),
        _row(
          'Courts & judges',
          'California Courts',
          () => _open('https://courts.ca.gov/'),
        ),
      ]),
  ];

  List<Widget> _government() => [
    _heading('${widget.stateName} leadership', 'Directory & rules'),
    _row('Past governors', 'Saved history & terms', () => _select('History')),
    _panel([
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(
          'How ${widget.stateName} government works',
          style: const TextStyle(fontSize: 13),
        ),
        subtitle: const Text(
          'Terms, representation & official directories',
          style: TextStyle(fontSize: 11),
        ),
        children: _leadershipRules(),
      ),
    ]),
    if (capitals[widget.stateId] != null)
      _panel([_row('State capital', capitals[widget.stateId]!)]),
    _notice(
      'Officeholders below reflect the app’s bundled records. Verify the latest officeholder with the official office.',
    ),
    if (widget.governmentEntries.isNotEmpty)
      ...widget.governmentEntries
    else
      _notice('No leadership records are available in this profile.'),
    if (widget.onVotingRules != null)
      _row(
        'Voter ID & rules guide',
        'State voting information',
        widget.onVotingRules,
      ),
    if (widget.onExploreMap != null)
      _row(
        'Explore map & local leaders',
        'Cities, counties, bills & districts',
        widget.onExploreMap,
      ),
  ];

  List<Widget> _pastGovernors() {
    final archive =
        _governorHistory['states']?[widget.stateId] as Map<String, dynamic>?;
    final people = archive?['people'] as List? ?? [];
    return [
      _heading('Past governors', widget.stateName),
      _notice(
        'Historical officeholders are separate from current leaders. Old office contacts are not shown as current contact information.',
      ),
      if (people.isEmpty)
        _notice(
          'No verified historical governor records have been added for ${widget.stateName} yet. This is a coverage gap, not a statement that there were no past governors.',
        ),
      if (archive != null) ...[
        _panel([
          Text(
            archive['coverage'] as String,
            style: TextStyle(color: _muted, fontSize: 11),
          ),
          _row(
            'Archive checked (UTC)',
            archive['verifiedAt'].toString().split('T').first,
          ),
          _row(
            archive['sourceName'] as String,
            'Official .gov archive',
            () => _open(archive['sourceUrl'] as String),
          ),
        ]),
        for (final person in people)
          _panel([
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                person['name'] as String,
                style: TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Former governor · ${(person['services'] as List).map((s) => s['period']).join(' / ')}',
                style: TextStyle(color: _muted, fontSize: 11),
              ),
              children: [
                for (final service in person['services'] as List) ...[
                  _row(
                    service['ordinal'] == null
                        ? 'Recorded service'
                        : 'Recorded service · #${service['ordinal']}',
                    service['period'] as String,
                  ),
                  if (service['serviceType'] != null)
                    _row('Service type', service['serviceType'] as String),
                  _row(
                    'Official source',
                    'Government biography & records',
                    () => _open(service['sourceUrl'] as String),
                  ),
                ],
              ],
            ),
          ]),
      ],
    ];
  }

  List<Widget> _office() => [
    _heading('Office & responsibilities'),
    _stats([
      ('Office', 'Governor', widget.stateName, null),
      ('Party', widget.governor?.party ?? 'Not listed', 'Bundled record', null),
      ('Jurisdiction', widget.stateId, 'Statewide', null),
    ]),
    _panel([
      _heading('Recorded terms'),
      if (widget.governor?.terms.isNotEmpty ?? false)
        for (final term in widget.governor!.terms) _row('Term', term)
      else
        _row('Term dates', 'Not supplied'),
    ]),
    _notice(
      'Governor responsibilities and powers vary by state. Consult the official office and state constitution for executive duties, legislation, budgets, appointments, and emergency authorities.',
    ),
    if (widget.governor?.website != null)
      _row(
        'Official governor website',
        'Office information',
        () => _open(widget.governor!.website!),
      ),
    if (widget.governor?.biography.isNotEmpty ?? false)
      _panel([
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text(
            'Biography from source',
            style: TextStyle(fontSize: 13),
          ),
          subtitle: const Text(
            'Bundled profile · source wording',
            style: TextStyle(fontSize: 10),
          ),
          children: widget.governor!.biography
              .map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    p,
                    style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
                  ),
                ),
              )
              .toList(),
        ),
      ]),
  ];

  List<Widget> _activities() => [
    _heading('Official activity', 'Coverage'),
    Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final filter in [
          'All',
          'Executive orders',
          'Legislation',
          'Budget',
        ])
          ChoiceChip(
            label: Text(filter, style: const TextStyle(fontSize: 11)),
            selected: _activity == filter,
            onSelected: (_) => setState(() => _activity = filter),
          ),
      ],
    ),
    const SizedBox(height: 14),
    _panel([
      _heading(_activity == 'All' ? 'Activity records' : _activity),
      Text(
        'No ${_activity == 'All' ? 'activity' : _activity.toLowerCase()} records connected yet.',
        style: TextStyle(color: _ink, fontSize: 13),
      ),
      const SizedBox(height: 8),
      Text(
        'This is a coverage gap in the app, not a statement that the governor has taken no action.',
        style: TextStyle(color: _muted, fontSize: 11, height: 1.5),
      ),
      if (widget.governor?.website != null)
        _row(
          'Check the official office',
          'Open website',
          () => _open(widget.governor!.website!),
        ),
    ]),
  ];

  List<Widget> _contact() {
    final g = widget.governor;
    return [
      _heading('Contact the office', 'Public office channels'),
      _panel([
        if (g?.website != null)
          _row(
            'Official governor website',
            Uri.tryParse(g!.website!)?.host ?? 'Website',
            () => _open(g.website!),
          )
        else
          _row('Official website', 'Not supplied'),
        if (g?.phone?.isNotEmpty ?? false)
          _row(
            'Public office phone',
            g!.phone!,
            () => _open('tel:${g.phone!.replaceAll(RegExp(r'[^0-9+]'), '')}'),
          )
        else
          _row('Public office phone', 'Not supplied'),
        _row('Mailing address', g?.address ?? 'Not supplied'),
        _row('Verified contact form', 'Not connected'),
        _row('Office locations directory', 'Not connected'),
      ]),
      _notice(
        'Contact details are from the bundled office record. Confirm them on the official website before use.',
      ),
    ];
  }

  List<Widget> _sources(Map<String, dynamic>? data) => [
    _heading('Sources & verification'),
    if (_leader)
      _panel([
        _heading('Governor profile', 'Bundled record'),
        _row(
          'Last recorded retrieval',
          widget.governor?.retrievedAt?.split('T').first ?? 'Not supplied',
        ),
        if (widget.governor?.sourceUrl != null)
          _row(
            'Profile source',
            'Original source',
            () => _open(widget.governor!.sourceUrl!),
          ),
        if (widget.governor?.website != null)
          _row(
            'Official office',
            'Open website',
            () => _open(widget.governor!.website!),
          ),
        _row('Activity records', 'Not connected'),
      ]),
    _panel([
      _heading('Population', data?['vintage'] as String? ?? 'Unavailable'),
      Text(
        data?['description'] as String? ?? 'Population dataset could not load.',
        style: TextStyle(color: _muted, fontSize: 12),
      ),
      _row(
        'Retrieved',
        data?['retrievedAt']?.toString().split('T').first ?? 'Not available',
      ),
      if (data?['url'] != null)
        _row(
          'Census population dataset',
          'Original dataset',
          () => _open(data!['url'] as String),
        ),
    ]),
    for (final source
        in (_indicators['sources'] as Map<String, dynamic>? ?? {}).values)
      _panel([
        _heading(source['agency'] as String),
        Text(
          source['dataset'] as String,
          style: TextStyle(color: _ink, fontSize: 12),
        ),
        _row(
          'Retrieved (UTC)',
          source['retrievedAt'].toString().split('T').first,
        ),
        Text(
          source['notes'] as String,
          style: TextStyle(color: _muted, fontSize: 11),
        ),
        for (final url in source['urls'] as List)
          _row(
            'Verified .gov source',
            Uri.parse(url as String).host,
            () => _open(url),
          ),
      ]),
    _panel([
      _heading('Official agency references'),
      _row(
        'BEA · State GDP',
        'Reference',
        () => _open('https://www.bea.gov/data/gdp/gdp-state'),
      ),
      _row(
        'Census · Income & housing',
        'Reference',
        () => _open('https://www.census.gov/programs-surveys/acs'),
      ),
      _row(
        'BLS · Employment',
        'Reference',
        () => _open('https://www.bls.gov/lau/'),
      ),
    ]),
    _notice(
      'Government indicators are bundled from verified .gov releases. Updates require a successful data refresh and app build; figures are not live. Governor activity is not connected.',
    ),
  ];
}

class _SlantedClipper extends CustomClipper<Path> {
  const _SlantedClipper();
  @override
  Path getClip(Size size) => Path()
    ..moveTo(5, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width - 5, size.height)
    ..lineTo(0, size.height)
    ..close();
  @override
  bool shouldReclip(covariant _SlantedClipper oldClipper) => false;
}

class _Sparkline extends CustomPainter {
  final List<double> values;
  final Color color;
  _Sparkline(this.values, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final low = values.reduce(math.min), high = values.reduce(math.max);
    final range = high - low;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = 4 + i / (values.length - 1) * math.max(0, size.width - 8);
      final y = range == 0
          ? size.height / 2
          : 3 + (1 - (values[i] - low) / range) * math.max(0, size.height - 6);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _Sparkline oldDelegate) =>
      color != oldDelegate.color || values != oldDelegate.values;
}
