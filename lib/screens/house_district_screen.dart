import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/data_provider.dart';
import '../services/congressional_district_service.dart';
import '../utils/search_handler.dart';
import 'lawmaker_detail_screen.dart';

typedef HouseDistrictLookup =
    Future<CongressionalDistrictLookupResult> Function(
      CongressionalDistrictAddress,
    );

/// Address matching only; the member and contact details stay in the local roster.
class HouseDistrictScreen extends StatefulWidget {
  const HouseDistrictScreen({
    super.key,
    required this.searchResult,
    this.lookup,
  });
  final SearchResult searchResult;
  final HouseDistrictLookup? lookup;
  @override
  State<HouseDistrictScreen> createState() => _HouseDistrictScreenState();
}

class _HouseDistrictScreenState extends State<HouseDistrictScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _street, _city, _zip;
  String? _state, _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final r = widget.searchResult;
    _street = TextEditingController(text: r.streetAddress);
    _city = TextEditingController(text: r.cityName);
    _zip = TextEditingController(
      text: RegExp(r'\b\d{5}\b').firstMatch(r.title)?.group(0),
    );
    _state = r.stateId;
  }

  @override
  void dispose() {
    _street.dispose();
    _city.dispose();
    _zip.dispose();
    super.dispose();
  }

  Future<void> _match() async {
    if (_busy || !_form.currentState!.validate()) return;
    final provider = context.read<MapDataProvider>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final address = CongressionalDistrictAddress(
        street: _street.text.trim(),
        city: _city.text.trim(),
        state: _state!,
        zip: _zip.text.trim(),
      );
      final result =
          await (widget.lookup ?? CongressionalDistrictService().lookup)(
            address,
          );
      if (!mounted) return;
      final match = result.match;
      if (result.status != CongressionalDistrictLookupStatus.matched ||
          match == null) {
        setState(
          () => _error =
              'We could not match one district. Check your full street address and try again.',
        );
        return;
      }
      if (match.stateAbbreviation != _state ||
          (provider.congressionalRoster != null &&
              match.congressionalSession !=
                  provider.congressionalRoster!.congress.toString())) {
        setState(
          () => _error =
              'The district could not be matched to the current roster. Please try again later.',
        );
        return;
      }
      final members = (provider.houseMembers?[match.stateAbbreviation] ?? [])
          .where((m) => m.districtNumber == match.districtNumber)
          .toList();
      if (members.length != 1) {
        setState(
          () => _error =
              'No current member is listed for this district. The seat may be vacant.',
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LawmakerDetailScreen(
            lawmaker: members.single,
            role: 'Representative',
            stateId: match.stateAbbreviation,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Address matching is unavailable. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F6FA),
    appBar: AppBar(
      title: const Text('Your House district'),
      backgroundColor: const Color(0xFF102D54),
      foregroundColor: Colors.white,
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'A ZIP code can cross district boundaries.',
                  style: TextStyle(color: Color(0xFF51647B)),
                ),
                const SizedBox(height: 20),
                _field(_street, 'Street address', const Key('house-street')),
                _field(_city, 'City', const Key('house-city')),
                DropdownButtonFormField<String>(
                  initialValue: _state,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'State or territory',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      {
                            ...SearchHandler.stateCodeToName,
                            'AS': 'American Samoa',
                            'GU': 'Guam',
                            'MP': 'Northern Mariana Islands',
                            'VI': 'U.S. Virgin Islands',
                          }.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _state = value),
                  validator: (value) =>
                      value == null ? 'Choose your state' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('house-zip'),
                  controller: _zip,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ZIP code',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      RegExp(
                        r'^\d{5}(?:-\d{4})?$',
                      ).hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Enter a 5-digit ZIP',
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(_error!),
                    ),
                  ),
                FilledButton(
                  onPressed: _busy ? null : _match,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF102D54),
                    minimumSize: const Size(0, 52),
                  ),
                  child: Text(_busy ? 'Matching…' : 'Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _field(TextEditingController controller, String label, Key key) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          key: key,
          controller: controller,
          enabled: !_busy,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          validator: (value) => (value?.trim().isEmpty ?? true)
              ? 'Enter your ${label.toLowerCase()}'
              : null,
        ),
      );
}
