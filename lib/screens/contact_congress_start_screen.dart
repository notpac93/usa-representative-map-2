import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/data_provider.dart';
import '../data/models.dart';
import '../design/civic_icons.dart';
import '../design/civic_palette.dart';
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
  static const _navy = CivicPalette.navy;
  static const _blue = CivicPalette.actionBlue;
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
      backgroundColor: CivicPalette.canvas,
      appBar: AppBar(
        title: const Text('Contact Congress'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ContactProgressHeader(matched: _match != null),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_match == null)
                          const _DistrictMapIllustration()
                        else
                          _DelegationPortraitStack(recipients: _recipients),
                        const SizedBox(height: 24),
                        Text(
                          _match == null
                              ? 'LET’S FIND YOUR DISTRICT'
                              : 'YOUR FEDERAL DELEGATION',
                          style: const TextStyle(
                            color: CivicPalette.teal,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _match == null
                              ? 'Where do you live?'
                              : 'These are your members',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: _navy,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.7,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _match == null
                              ? 'For state residents, your full home address identifies your two U.S. senators and one district-specific House representative. Territories have a House Delegate or Resident Commissioner but no U.S. senators.'
                              : 'We matched your address to one congressional district. Review the offices before writing.',
                          style: const TextStyle(
                            color: CivicPalette.mutedInk,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_match == null)
                          _buildAddressForm(states)
                        else
                          _buildDelegationResult(states),
                      ],
                    ),
                  ),
                ),
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
            _ResponsiveFieldPair(
              firstFlex: 3,
              first: TextFormField(
                key: const Key('district-street-field'),
                controller: _streetController,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.streetAddressLine1],
                decoration: _fieldDecoration(
                  'Street address',
                  hint: '123 Main Street',
                  icon: CivicIcons.homeAddress,
                ),
                validator: (value) =>
                    _required(value, 'Enter your street address'),
              ),
              second: TextFormField(
                key: const Key('district-zip-field'),
                controller: _zipController,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.postalCode],
                decoration: _fieldDecoration(
                  'ZIP code',
                  icon: CivicIcons.address,
                ),
                validator: (value) {
                  if (!RegExp(
                    r'^\d{5}(?:-\d{4})?$',
                  ).hasMatch((value ?? '').trim())) {
                    return 'Enter a 5-digit ZIP';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start with your street and ZIP. We’ll fill in the city and state when we recognize the ZIP.',
              style: TextStyle(color: CivicPalette.subtleInk, fontSize: 12),
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
            const SizedBox(height: 16),
            _ResponsiveFieldPair(
              first: TextFormField(
                key: const Key('district-city-field'),
                controller: _cityController,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.addressCity],
                decoration: _fieldDecoration('City', icon: CivicIcons.city),
                validator: (value) => _required(value, 'Enter your city'),
              ),
              second: DropdownButtonFormField<String>(
                key: const Key('district-state-field'),
                initialValue: _stateCode,
                isExpanded: true,
                decoration: _fieldDecoration(
                  'State or territory',
                  icon: CivicIcons.state,
                ),
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
                validator: (value) =>
                    value == null ? 'Choose your state' : null,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CivicPalette.blueTint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(CivicIcons.privacy, color: _blue, size: 21),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Why we ask: District lines can split a city or ZIP code. We use your address only to find the correct offices and prepare the information those offices require. We do not sell it.',
                      style: TextStyle(color: CivicPalette.blue, height: 1.4),
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
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const Key('find-delegation-button'),
                onPressed: _lookingUp ? null : _findDelegation,
                icon: _lookingUp
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(CivicIcons.matched),
                label: Text(
                  _lookingUp ? 'Matching your district…' : 'Find my members',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 54),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  backgroundColor: CivicPalette.actionBlue,
                  shape: const StadiumBorder(),
                ),
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
            color: CivicPalette.greenTint,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Icon(CivicIcons.success, color: Color(0xFF047857)),
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
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            color: CivicPalette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: CivicPalette.border),
            ),
            child: ListTile(
              minVerticalPadding: 14,
              leading: _RecipientAvatar(recipient: recipient, size: 46),
              title: Text(
                recipient.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(recipient.role),
              trailing: const Icon(
                CivicIcons.success,
                color: Color(0xFF047857),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const Key('continue-to-compose-button'),
            onPressed: () => _continueToCompose(stateName),
            icon: const Icon(CivicIcons.write),
            label: Text(
              'Write to ${_recipients.length} ${_recipients.length == 1 ? 'office' : 'offices'}',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 54),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              backgroundColor: CivicPalette.teal,
              shape: const StadiumBorder(),
            ),
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
              photoAsset: senator.photoLocalPath == null
                  ? null
                  : 'assets/img/${senator.photoLocalPath}',
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
          photoAsset: matchingHouse.single.photoLocalPath == null
              ? null
              : 'assets/img/${matchingHouse.single.photoLocalPath}',
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

  InputDecoration _fieldDecoration(
    String label, {
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, color: CivicPalette.blue),
      filled: true,
      fillColor: CivicPalette.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: CivicPalette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: CivicPalette.actionBlue, width: 2),
      ),
    );
  }
}

class _ResponsiveFieldPair extends StatelessWidget {
  const _ResponsiveFieldPair({
    required this.first,
    required this.second,
    this.firstFlex = 1,
  });

  final Widget first;
  final Widget second;
  final int firstFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(children: [first, const SizedBox(height: 14), second]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: firstFlex, child: first),
            const SizedBox(width: 14),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class _DistrictMapIllustration extends StatelessWidget {
  const _DistrictMapIllustration();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'A neighborhood map marking a home address',
      child: SizedBox(
        height: 184,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              const Positioned.fill(
                child: ColoredBox(color: CivicPalette.blueTint),
              ),
              Positioned(
                left: -34,
                right: -34,
                top: 38,
                child: Transform.rotate(
                  angle: 0.14,
                  child: const SizedBox(
                    height: 18,
                    child: ColoredBox(color: CivicPalette.surface),
                  ),
                ),
              ),
              Positioned(
                left: -34,
                right: -34,
                bottom: 36,
                child: Transform.rotate(
                  angle: -0.11,
                  child: const SizedBox(
                    height: 18,
                    child: ColoredBox(color: CivicPalette.surface),
                  ),
                ),
              ),
              Positioned(
                left: 92,
                top: 18,
                child: _MapBlock(
                  color: CivicPalette.purpleLine,
                  width: 84,
                  height: 42,
                ),
              ),
              Positioned(
                right: 40,
                top: 78,
                child: _MapBlock(
                  color: CivicPalette.tealLine,
                  width: 92,
                  height: 50,
                ),
              ),
              Positioned(
                left: 38,
                bottom: 18,
                child: _MapBlock(
                  color: CivicPalette.blueLine,
                  width: 112,
                  height: 42,
                ),
              ),
              Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: CivicPalette.actionBlue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x331E3A8A),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    CivicIcons.homeAddress,
                    color: Colors.white,
                    size: 28,
                    fill: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapBlock extends StatelessWidget {
  const _MapBlock({
    required this.color,
    required this.width,
    required this.height,
  });

  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _DelegationPortraitStack extends StatelessWidget {
  const _DelegationPortraitStack({required this.recipients});

  final List<ContactCongressRecipient> recipients;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Your matched congressional delegation',
      child: SizedBox(
        height: 92,
        child: Center(
          child: SizedBox(
            width: 62 + ((recipients.length - 1).clamp(0, 4) * 42),
            child: Stack(
              children: [
                for (var index = 0; index < recipients.length; index++)
                  Positioned(
                    left: index * 42,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: CivicPalette.canvas,
                          width: 4,
                        ),
                      ),
                      child: _RecipientAvatar(
                        recipient: recipients[index],
                        size: 68,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipientAvatar extends StatelessWidget {
  const _RecipientAvatar({required this.recipient, required this.size});

  final ContactCongressRecipient recipient;
  final double size;

  @override
  Widget build(BuildContext context) {
    final photo = recipient.photoAsset;
    final initials = recipient.name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: recipient.chamber == CongressionalChamber.house
          ? CivicPalette.tealLine
          : CivicPalette.blueLine,
      foregroundImage: photo == null || photo.isEmpty
          ? null
          : AssetImage(photo),
      child: photo == null || photo.isEmpty
          ? Text(
              initials,
              style: const TextStyle(
                color: CivicPalette.navy,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }
}

class _ContactProgressHeader extends StatelessWidget {
  const _ContactProgressHeader({required this.matched});

  final bool matched;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: matched
          ? 'District matched. Next: write your message.'
          : 'Step 1 of 4: Find your district',
      child: Container(
        color: CivicPalette.surface,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: CivicPalette.blueTint,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    matched ? CivicIcons.success : CivicIcons.address,
                    color: matched
                        ? CivicPalette.green
                        : CivicPalette.actionBlue,
                    size: 21,
                    fill: matched ? 1 : 0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        matched ? 'District matched' : 'Find your district',
                        style: const TextStyle(
                          color: CivicPalette.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text(
                        'Step 1 of 4',
                        style: TextStyle(
                          color: CivicPalette.subtleInk,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const _ProgressDots(current: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 1; index <= 4; index++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: index == current ? 20 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: index <= current
                  ? CivicPalette.actionBlue
                  : CivicPalette.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          if (index != 4) const SizedBox(width: 5),
        ],
      ],
    );
  }
}
