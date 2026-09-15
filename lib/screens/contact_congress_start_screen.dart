import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/data_provider.dart';
import '../data/models.dart';
import '../services/congressional_delivery_service.dart';
import '../services/congressional_district_service.dart';
import '../utils/search_handler.dart';
import 'contact_congress_screen.dart';

/// Address-first entry point for contacting a constituent's federal delegation.
///
/// A state alone can identify senators, but never a district-specific House
/// member. This screen does not advance until an exact address resolves to one
/// current congressional district and one roster entry.
class ContactCongressStartScreen extends StatefulWidget {
  const ContactCongressStartScreen({
    super.key,
    this.states,
    this.senatorsByState,
    this.houseMembersByState,
    this.districtLookup,
    this.deliveryGateway = const PlaceholderCongressionalDeliveryGateway(),
  });

  final List<StateRecord>? states;
  final Map<String, List<Senator>>? senatorsByState;
  final Map<String, List<Representative>>? houseMembersByState;
  final ContactDistrictLookup? districtLookup;
  final CongressionalDeliveryGateway deliveryGateway;

  @override
  State<ContactCongressStartScreen> createState() =>
      _ContactCongressStartScreenState();
}

class _ContactCongressStartScreenState
    extends State<ContactCongressStartScreen> {
  static const _navy = Color(0xFF0F172A);
  static const _blue = Color(0xFF1D4ED8);
  static const _territories = <String, ({String name, String fips})>{
    'AS': (name: 'American Samoa', fips: '60'),
    'GU': (name: 'Guam', fips: '66'),
    'MP': (name: 'Northern Mariana Islands', fips: '69'),
    'PR': (name: 'Puerto Rico', fips: '72'),
    'VI': (name: 'U.S. Virgin Islands', fips: '78'),
  };

  final _formKey = GlobalKey<FormState>();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipController = TextEditingController();

  String? _stateCode;
  String? _localityNotice;
  String? _lastZipLookup;
  bool _lookingUp = false;
  String? _error;
  CongressionalDistrictMatch? _match;
  List<ContactCongressRecipient> _recipients = const [];

  @override
  void initState() {
    super.initState();
    _zipController.addListener(_autofillLocalityFromZip);
  }

  @override
  void dispose() {
    _zipController.removeListener(_autofillLocalityFromZip);
    _streetController.dispose();
    _cityController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MapDataProvider>();
    final states = [
      ...?widget.states ?? provider.atlas?.states,
      if (widget.states == null)
        for (final entry in _territories.entries)
          if (provider.houseMembers?.containsKey(entry.key) ?? false)
            StateRecord(
              id: entry.key,
              name: entry.value.name,
              fips: entry.value.fips,
              path: '',
              bbox: const [],
              centroid: const [],
            ),
    ]..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Contact Congress'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const _ContactProgressHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  Text(
                    _match == null
                        ? 'Find your federal delegation'
                        : 'Your federal delegation',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: _navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _match == null
                        ? 'For state residents, your full home address identifies your two U.S. senators and one district-specific House representative. Territories have a House Delegate or Resident Commissioner but no U.S. senators.'
                        : 'We matched your address to one congressional district. Review the offices before writing.',
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_match == null)
                    _buildAddressForm(states)
                  else
                    _buildDelegationResult(states),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressForm(List<StateRecord> states) {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('district-street-field'),
              controller: _streetController,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.streetAddressLine1],
              decoration: _fieldDecoration(
                'Street address',
                hint: '123 Main Street',
              ),
              validator: (value) =>
                  _required(value, 'Enter your street address'),
            ),
            const SizedBox(height: 7),
            const Text(
              'Enter your street and ZIP first. We’ll fill the city and state when the ZIP is recognized.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('district-zip-field'),
              controller: _zipController,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.postalCode],
              decoration: _fieldDecoration('ZIP code'),
              validator: (value) {
                if (!RegExp(
                  r'^\d{5}(?:-\d{4})?$',
                ).hasMatch((value ?? '').trim())) {
                  return 'Enter a 5-digit ZIP';
                }
                return null;
              },
            ),
            if (_localityNotice != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  _localityNotice!,
                  key: const Key('zip-autofill-notice'),
                  style: const TextStyle(
                    color: Color(0xFF047857),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('district-city-field'),
              controller: _cityController,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.addressCity],
              decoration: _fieldDecoration('City'),
              validator: (value) => _required(value, 'Enter your city'),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: const Key('district-state-field'),
              initialValue: _stateCode,
              isExpanded: true,
              decoration: _fieldDecoration('State or territory'),
              items: states
                  .map(
                    (state) => DropdownMenuItem(
                      value: state.id,
                      child: Text(state.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() {
                _stateCode = value;
                _localityNotice = null;
              }),
              validator: (value) => value == null ? 'Choose your state' : null,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, color: _blue, size: 21),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Why we ask: District lines can split a city or ZIP code. We use your address only to find the correct offices and prepare the information those offices require. We do not sell it.',
                      style: TextStyle(color: Color(0xFF1E3A8A), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  key: const Key('district-lookup-error'),
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    height: 1.35,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('find-delegation-button'),
              onPressed: _lookingUp ? null : _findDelegation,
              icon: _lookingUp
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.location_searching),
              label: Text(
                _lookingUp ? 'Matching your district…' : 'Find my members',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: _blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _autofillLocalityFromZip() async {
    final zip = _zipController.text.trim();
    final zip5 = RegExp(r'^\d{5}').firstMatch(zip)?.group(0);
    if (zip5 == null || zip5 == _lastZipLookup) return;
    _lastZipLookup = zip5;
    final record = await SearchHandler().findZip(zip5);
    if (!mounted || record == null || !_zipController.text.startsWith(zip5)) {
      return;
    }
    final filledCity = _cityController.text.trim().isEmpty;
    final filledState = _stateCode == null;
    if (filledCity) _cityController.text = record.city;
    setState(() {
      if (filledState) _stateCode = record.state;
      if (filledCity || filledState) {
        _localityNotice =
            '${record.city}, ${record.state} filled from ZIP $zip5.';
      }
    });
  }

  Widget _buildDelegationResult(List<StateRecord> states) {
    final stateName = _stateName(states, _match!.stateAbbreviation);
    final district = _match!.isAtLarge
        ? '${_match!.stateAbbreviation} at-large'
        : '${_match!.stateAbbreviation}-${_match!.districtNumber}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('district-match-success'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF047857)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Address matched • $district',
                  style: const TextStyle(
                    color: Color(0xFF065F46),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: _changeAddress,
                child: const Text('Change'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final recipient in _recipients)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFDBEAFE),
                foregroundColor: _blue,
                child: Icon(
                  recipient.chamber == CongressionalChamber.house
                      ? Icons.home_work_outlined
                      : Icons.account_balance_outlined,
                ),
              ),
              title: Text(
                recipient.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(recipient.role),
              trailing: const Icon(
                Icons.check_circle,
                color: Color(0xFF047857),
              ),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('continue-to-compose-button'),
          onPressed: () => _continueToCompose(stateName),
          icon: const Icon(Icons.edit_outlined),
          label: Text(
            'Write to ${_recipients.length} ${_recipients.length == 1 ? 'office' : 'offices'}',
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: _blue,
          ),
        ),
        const SizedBox(height: 12),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text(
            'What about other members or committees?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          children: const [
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'CWC and SCWC deliver to individual member offices, not committee, leadership, or support offices. Offices generally prioritize their own constituents, so this flow sends only to the federal delegation tied to your home address. We can provide separate official-directory links for other offices without representing them as your representatives.',
                style: TextStyle(color: Color(0xFF475569), height: 1.45),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _findDelegation() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _lookingUp = true;
      _error = null;
    });

    final address = CongressionalDistrictAddress(
      street: _streetController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateCode!,
      zip: _zipController.text.trim(),
    );

    try {
      final result = widget.districtLookup != null
          ? await widget.districtLookup!(address)
          : await CongressionalDistrictService().lookup(address);
      if (!mounted) return;
      if (result.status != CongressionalDistrictLookupStatus.matched ||
          result.match == null ||
          result.match!.stateAbbreviation != _stateCode) {
        setState(() {
          _error = result.status == CongressionalDistrictLookupStatus.ambiguous
              ? 'This address matched more than one district. Please add an apartment or unit and try again; we will not guess.'
              : 'We could not match that complete address to one congressional district. Check it and try again; we will not guess.';
        });
        return;
      }

      final provider = context.read<MapDataProvider>();
      final senators =
          (widget.senatorsByState ?? provider.senators)?[_stateCode] ??
          const <Senator>[];
      final houseMembers =
          (widget.houseMembersByState ?? provider.houseMembers)?[_stateCode] ??
          const <Representative>[];
      final matchingHouse = houseMembers
          .where(
            (member) => member.districtNumber == result.match!.districtNumber,
          )
          .toList(growable: false);
      if (matchingHouse.length != 1) {
        setState(() {
          _error =
              'Your district was found, but the current member roster did not identify exactly one House office. We will not guess or send to the wrong office.';
        });
        return;
      }

      final recipients = <ContactCongressRecipient>[
        for (final senator in senators)
          if ((senator.contactUrl ?? senator.website)?.isNotEmpty ?? false)
            ContactCongressRecipient(
              name: senator.name,
              role: 'U.S. Senator for ${_stateCode!}',
              officialUrl: senator.contactUrl ?? senator.website!,
              bioguideId: senator.bioguideId,
              chamber: CongressionalChamber.senate,
            ),
        ContactCongressRecipient(
          name: matchingHouse.single.name,
          role: result.match!.isAtLarge
              ? 'U.S. House delegate/representative at-large'
              : 'U.S. Representative • District ${result.match!.districtNumber}',
          officialUrl:
              matchingHouse.single.contactUrl ??
              matchingHouse.single.website ??
              '',
          bioguideId: matchingHouse.single.bioguideId,
          chamber: CongressionalChamber.house,
        ),
      ];
      if (recipients.any((recipient) => !recipient.hasVerifiedOfficialUrl)) {
        setState(() {
          _error =
              'We found your district, but one official contact link is missing or could not be verified. Please try again later.';
        });
        return;
      }

      setState(() {
        _match = result.match;
        _recipients = recipients;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'District matching is temporarily unavailable. Nothing was sent. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  void _changeAddress() {
    setState(() {
      _match = null;
      _recipients = const [];
      _error = null;
    });
  }

  void _continueToCompose(String stateName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContactCongressScreen(
          stateName: stateName,
          recipients: _recipients,
          initialAddress: _match!.matchedAddress,
          deliveryGateway: widget.deliveryGateway,
        ),
      ),
    );
  }

  String _stateName(List<StateRecord> states, String code) {
    for (final state in states) {
      if (state.id == code) return state.name;
    }
    return code;
  }

  String? _required(String? value, String message) =>
      (value ?? '').trim().isEmpty ? message : null;

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
    );
  }
}

class _ContactProgressHeader extends StatelessWidget {
  const _ContactProgressHeader();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step 1 of 4: Find your district',
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
        child: const Column(
          children: [
            Row(
              children: [
                Expanded(child: _ProgressBar(active: true)),
                SizedBox(width: 6),
                Expanded(child: _ProgressBar()),
                SizedBox(width: 6),
                Expanded(child: _ProgressBar()),
                SizedBox(width: 6),
                Expanded(child: _ProgressBar()),
              ],
            ),
            SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Find your district • 1 of 4',
                style: TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({this.active = false});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF1D4ED8) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
