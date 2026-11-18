import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/federal_officials.dart';
import '../services/federal_officials_service.dart';
import 'leader_quick_profile_screen.dart';

String _day(DateTime date) => DateFormat.yMMMd().format(date.toUtc());

/// Text only: a successor never competes with the serving official's portrait.
class FederalTransitionNotice extends StatelessWidget {
  final FederalSnapshot snapshot;
  final FederalOfficeView view;
  const FederalTransitionNotice({
    super.key,
    required this.snapshot,
    required this.view,
  });
  @override
  Widget build(BuildContext context) {
    final t = view.incoming;
    if (t == null && !view.awaitingVerification) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('federal_transition_notice'),
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_outlined, size: 20, color: colors.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  view.reelected
                      ? 'Reelected · next term'
                      : view.awaitingVerification
                      ? 'Transition awaiting verification'
                      : 'Incoming · certified',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (t != null) ...[
                  const SizedBox(height: 4),
                  if (!view.reelected)
                    Text(
                      snapshot.people[t.personId]!.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text(
                    'Scheduled start: ${_day(t.scheduledStart!)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
                if (view.awaitingVerification)
                  const Text(
                    'Official confirmation of service is still pending.',
                    style: TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FederalOfficialProfileScreen extends StatefulWidget {
  final String officeId;
  final FederalSnapshot? initialSnapshot;
  final DateTime Function()? clock;
  final VoidCallback? onRecords;
  final String? recordsPersonId;
  const FederalOfficialProfileScreen({
    super.key,
    required this.officeId,
    this.initialSnapshot,
    this.clock,
    this.onRecords,
    this.recordsPersonId,
  });
  @override
  State<FederalOfficialProfileScreen> createState() =>
      _FederalOfficialProfileScreenState();
}

class _FederalOfficialProfileScreenState
    extends State<FederalOfficialProfileScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  final service = FederalOfficialsService.instance;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialSnapshot == null) service.load();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      service.refresh();
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: service,
    builder: (context, _) {
      final snapshot = widget.initialSnapshot ?? service.snapshot;
      if (snapshot == null || !snapshot.offices.containsKey(widget.officeId)) {
        return Scaffold(
          appBar: AppBar(title: const Text('Federal office')),
          body: const Center(child: Text('Official records are unavailable.')),
        );
      }
      final view = snapshot.view(
        widget.officeId,
        widget.clock?.call() ?? DateTime.now(),
      );
      final term = view.current;
      final person = term == null ? null : snapshot.people[term.personId];
      return LeaderQuickProfileScreen(
        name: person?.name ?? 'Service awaiting verification',
        role: view.office.title,
        jurisdiction: view.office.jurisdiction,
        party: person?.party,
        photoPath: person?.photoLocalPath,
        phone: term?.contact['phone'],
        address: term?.contact['address'],
        website: term?.contact['website'],
        statusPanel: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Text(
              term == null
                  ? 'No current occupant verified in this snapshot.'
                  : 'Serving now',
              key: const Key('federal_service_status'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              'Official records checked ${_day(snapshot.publishedAt)}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (DateTime.now().toUtc().difference(snapshot.publishedAt) >
                const Duration(hours: 48))
              const Text(
                'This snapshot is over 48 hours old. Check the official source for recent changes.',
                style: TextStyle(fontSize: 11),
              ),
            FederalTransitionNotice(snapshot: snapshot, view: view),
            TextButton.icon(
              onPressed: () => _showSources(context, snapshot, view.office.id),
              icon: const Icon(Icons.verified_outlined, size: 16),
              label: const Text('Official sources and service history'),
            ),
            if (widget.initialSnapshot == null && service.refreshError != null)
              Text(service.refreshError!, style: const TextStyle(fontSize: 11)),
          ],
        ),
        onDetails:
            (widget.recordsPersonId == null ||
                    widget.recordsPersonId == term?.personId
                ? widget.onRecords
                : null) ??
            () => _showSources(context, snapshot, view.office.id),
      );
    },
  );
  void _showSources(
    BuildContext context,
    FederalSnapshot snapshot,
    String officeId,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Official sources and service history',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Incoming cards appear only after certification, within 90 days of the scheduled start. They disappear at a verified handoff, or seven days after the scheduled start if confirmation is pending.',
              ),
              for (final t in snapshot.terms.values.where(
                (t) => t.officeId == officeId,
              )) ...[
                const Divider(),
                Text(
                  '${snapshot.people[t.personId]!.name} · ${t.status}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (t.scheduledStart != null)
                  Text('Scheduled start: ${_day(t.scheduledStart!)}'),
                if (t.actualStart != null)
                  Text('Verified service start: ${_day(t.actualStart!)}'),
                for (final id in t.evidenceIds)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      snapshot.sources[snapshot.evidence[id]!.sourceId]!.name,
                    ),
                    subtitle: Text(
                      '${snapshot.evidence[id]!.claim} · ${_day(snapshot.evidence[id]!.retrievedAt)}',
                    ),
                    trailing: const Icon(Icons.open_in_new, size: 16),
                    onTap: () => launchUrl(
                      Uri.parse(snapshot.evidence[id]!.url),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class FederalOfficialsScreen extends StatefulWidget {
  const FederalOfficialsScreen({super.key});
  @override
  State<FederalOfficialsScreen> createState() => _FederalOfficialsScreenState();
}

class _FederalOfficialsScreenState extends State<FederalOfficialsScreen> {
  String query = '';
  @override
  void initState() {
    super.initState();
    FederalOfficialsService.instance.load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Federal officials')),
    body: AnimatedBuilder(
      animation: FederalOfficialsService.instance,
      builder: (context, _) {
        final snapshot = FederalOfficialsService.instance.snapshot;
        if (snapshot == null) {
          return const Center(child: Text('Loading official federal records…'));
        }
        final offices =
            snapshot.offices.values.where((o) {
              final v = snapshot.view(o.id, DateTime.now());
              final names = [v.current, v.incoming]
                  .whereType<FederalTerm>()
                  .map((t) => snapshot.people[t.personId]!.name)
                  .join(' ');
              return '${o.title} ${o.jurisdiction} $names'
                  .toLowerCase()
                  .contains(query.toLowerCase());
            }).toList()..sort(
              (a, b) => '${a.branch} ${a.state} ${a.title} ${a.id}'.compareTo(
                '${b.branch} ${b.state} ${b.title} ${b.id}',
              ),
            );
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Search name, state abbreviation, or office',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => query = v),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: offices.length,
                itemBuilder: (context, i) {
                  final o = offices[i];
                  final v = snapshot.view(o.id, DateTime.now());
                  return ListTile(
                    title: Text(
                      v.current == null
                          ? 'Service awaiting verification'
                          : snapshot.people[v.current!.personId]!.name,
                    ),
                    subtitle: Text('${o.title} · ${o.jurisdiction}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            FederalOfficialProfileScreen(officeId: o.id),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}
