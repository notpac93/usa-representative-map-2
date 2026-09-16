import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../design/civic_icons.dart';
import '../design/civic_palette.dart';
import '../services/contact_congress_verification_service.dart';
import '../services/congressional_delivery_service.dart';
import '../services/congressional_district_service.dart';

class ContactCongressRecipient {
  final String name;
  final String role;
  final String officialUrl;
  final String? bioguideId;
  final String? photoAsset;
  final CongressionalChamber chamber;

  const ContactCongressRecipient({
    required this.name,
    required this.role,
    required this.officialUrl,
    required this.chamber,
    this.bioguideId,
    this.photoAsset,
  });

  bool get hasVerifiedOfficialUrl {
    final uri = Uri.tryParse(officialUrl);
    return uri != null &&
        uri.scheme == 'https' &&
        (uri.host == 'house.gov' ||
            uri.host.endsWith('.house.gov') ||
            uri.host == 'senate.gov' ||
            uri.host.endsWith('.senate.gov'));
  }
}

typedef ContactDistrictLookup =
    Future<CongressionalDistrictLookupResult> Function(
      CongressionalDistrictAddress address,
    );

/// A one-message congressional submission flow.
///
/// The UI submits only through [CongressionalDeliveryGateway]. The default
/// placeholder exercises the complete flow without transmitting anything.
class ContactCongressScreen extends StatefulWidget {
  final String stateName;
  final List<ContactCongressRecipient> recipients;
  final String? initialAddress;
  final CongressionalAddressProof? addressProof;
  final List<Representative> houseCandidates;
  final ContactDistrictLookup? districtLookup;
  final ContactCongressVerificationGateway? verificationGateway;
  final CongressionalDeliveryGateway deliveryGateway;

  const ContactCongressScreen({
    super.key,
    required this.stateName,
    required this.recipients,
    this.initialAddress,
    this.addressProof,
    this.houseCandidates = const [],
    this.districtLookup,
    this.verificationGateway,
    this.deliveryGateway = const PlaceholderCongressionalDeliveryGateway(),
  });

  @override
  State<ContactCongressScreen> createState() => _ContactCongressScreenState();
}

class _ContactCongressScreenState extends State<ContactCongressScreen> {
  static const _navy = CivicPalette.navy;
  static const _blue = CivicPalette.actionBlue;
  static const _topics = <String>[
    'Choose a topic',
    'Budget and economy',
    'Education',
    'Environment and energy',
    'Health care',
    'Immigration',
    'Veterans',
    'Other',
  ];

  final _composeKey = GlobalKey<FormState>();
  final _detailsKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  late final TextEditingController _addressController;

  int _step = 0;
  String _topic = _topics.first;
  bool _attested = false;
  DateTime? _attestedAt;
  bool _resolvingDistrict = false;
  bool _submittingDirect = false;
  String? _districtNotice;
  ContactCongressRecipient? _resolvedHouseRecipient;
  CongressionalDeliveryResult? _deliveryResult;
  late final IdempotentCongressionalDeliveryService _deliveryService;
  late final ContactCongressVerificationGateway _verificationGateway;
  late CongressionalAddressProof _addressProof;
  EmailVerificationProof? _emailProof;
  final Set<String> _selectedRecipientKeys = {};

  List<ContactCongressRecipient> get _recipients => [
    ...widget.recipients,
    if (_resolvedHouseRecipient != null) _resolvedHouseRecipient!,
  ];

  List<ContactCongressRecipient> get _selectedRecipients => _recipients
      .where(
        (recipient) =>
            _selectedRecipientKeys.contains(_recipientKey(recipient)),
      )
      .toList(growable: false);

  bool get _addressAlreadyMatched =>
      widget.initialAddress != null && widget.houseCandidates.isEmpty;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: widget.initialAddress);
    _deliveryService = IdempotentCongressionalDeliveryService(
      widget.deliveryGateway,
    );
    _verificationGateway =
        widget.verificationGateway ??
        PreviewContactCongressVerificationGateway();
    _addressProof =
        widget.addressProof ??
        CongressionalAddressProof.preview(address: widget.initialAddress ?? '');
    _selectedRecipientKeys.addAll(widget.recipients.map(_recipientKey));
    _emailController.addListener(_invalidateChangedEmailProof);
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _nameController.dispose();
    _emailController.removeListener(_invalidateChangedEmailProof);
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _invalidateChangedEmailProof() {
    final proof = _emailProof;
    if (proof == null || proof.matches(_emailController.text)) return;
    setState(() => _emailProof = null);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) _goToPreviousStep();
      },
      child: Scaffold(
        backgroundColor: CivicPalette.canvas,
        appBar: AppBar(
          leading: BackButton(onPressed: _goBack),
          title: const Text('Contact Congress'),
          backgroundColor: _navy,
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: Column(
            children: [
              _ProgressHeader(currentStep: _step),
              Expanded(
                child: IndexedStack(
                  index: _step,
                  children: [
                    _buildComposeStep(),
                    _buildDetailsStep(),
                    _buildReviewStep(),
                  ],
                ),
              ),
              if (_step < 2) _buildBottomNavigation(),
            ],
          ),
        ),
      ),
    );
  }

  void _goBack() {
    if (_step > 0) {
      _goToPreviousStep();
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _goToPreviousStep() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _step--);
  }

  Widget _buildComposeStep() {
    return Form(
      key: _composeKey,
      child: _GuidedStepScroll(
        key: const Key('contact-compose-step'),
        artwork: const _ContactStepArtwork(
          icon: CivicIcons.write,
          accent: CivicPalette.teal,
          tint: CivicPalette.tealTint,
          secondary: CivicPalette.blueLine,
        ),
        eyebrow: 'WRITE ONE MESSAGE',
        accent: CivicPalette.teal,
        title: 'Write once. Contact each office.',
        description:
            'Write one message and choose which of your congressional offices should receive it.',
        children: [
          _RecipientsCard(
            recipients: _recipients,
            selectedRecipientKeys: _selectedRecipientKeys,
            recipientKey: _recipientKey,
            onChanged: (recipient, selected) {
              setState(() {
                final key = _recipientKey(recipient);
                if (selected) {
                  _selectedRecipientKeys.add(key);
                } else {
                  _selectedRecipientKeys.remove(key);
                }
              });
            },
          ),
          if (_selectedRecipients.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Select at least one office to continue.',
                style: TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
              ),
            ),
          if (widget.houseCandidates.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Your House representative will be added only after your exact district is matched.',
              style: TextStyle(color: Color(0xFF475569), fontSize: 13),
            ),
          ],
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            initialValue: _topic,
            isExpanded: true,
            decoration: _fieldDecoration('Topic', icon: CivicIcons.topic),
            items: _topics
                .map(
                  (topic) => DropdownMenuItem(value: topic, child: Text(topic)),
                )
                .toList(),
            onChanged: (value) =>
                setState(() => _topic = value ?? _topics.first),
            validator: (value) =>
                value == _topics.first ? 'Choose a topic' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('contact-subject-field'),
            controller: _subjectController,
            textCapitalization: TextCapitalization.sentences,
            decoration: _fieldDecoration('Subject', icon: CivicIcons.subject),
            maxLength: 100,
            validator: _required,
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: const Key('contact-message-field'),
            controller: _messageController,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            minLines: 7,
            maxLines: 12,
            maxLength: 4000,
            decoration: _fieldDecoration(
              'Your message',
              hint:
                  'Share what you want Congress to know and the action you want taken.',
              icon: CivicIcons.message,
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) return 'Write your message';
              if (value!.trim().length < 20) return 'Add a little more detail';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    return Form(
      key: _detailsKey,
      child: _GuidedStepScroll(
        key: const Key('contact-details-step'),
        artwork: const _ContactStepArtwork(
          icon: CivicIcons.verified,
          accent: CivicPalette.actionBlue,
          tint: CivicPalette.blueTint,
          secondary: CivicPalette.purpleLine,
        ),
        eyebrow: 'REPLIES AND VERIFICATION',
        accent: CivicPalette.actionBlue,
        title: 'Where replies go',
        description: _addressAlreadyMatched
            ? 'Your address is already matched to these offices. Add your name and email so they can accept and reply to your message.'
            : 'Congressional offices ask for these details to confirm that you are a constituent and to reply.',
        children: [
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            decoration: _fieldDecoration('Full name', icon: CivicIcons.profile),
            validator: _required,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: _fieldDecoration(
              'Email address',
              icon: CivicIcons.message,
            ),
            validator: (value) {
              final email = (value ?? '').trim();
              if (email.isEmpty) return 'Enter your email address';
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 9),
          _EmailVerificationStatus(
            verified: _emailProof?.matches(_emailController.text) ?? false,
            preview:
                _emailProof?.mode == ContactCongressVerificationMode.preview,
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('contact-address-field'),
            controller: _addressController,
            readOnly: _addressAlreadyMatched,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.fullStreetAddress],
            decoration: _fieldDecoration(
              'Home address',
              hint: 'Street, city, state, and ZIP',
              icon: CivicIcons.homeAddress,
            ),
            validator: (value) {
              final address = (value ?? '').trim();
              if (address.isEmpty) return 'Enter your home address';
              if (!RegExp(r'\d').hasMatch(address) || address.length < 8) {
                return 'Enter a complete home address';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          if (_addressAlreadyMatched) ...[
            const Row(
              children: [
                Icon(CivicIcons.success, color: Color(0xFF047857), size: 18),
                SizedBox(width: 7),
                Text(
                  'Matched to your federal delegation',
                  style: TextStyle(
                    color: Color(0xFF047857),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.all(14),
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
                    'Why we ask: Congressional offices use your home address to determine whether you are a constituent. To find your House district, we send the address to the official U.S. Census Geocoder. This app does not store it.',
                    style: TextStyle(color: Color(0xFF1E3A8A), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            key: const Key('contact-attestation'),
            value: _attested,
            onChanged: (value) {
              setState(() {
                _attested = value ?? false;
                _attestedAt = _attested ? DateTime.now().toUtc() : null;
              });
            },
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text('I live at this address in ${widget.stateName}.'),
            subtitle: const Text('I authorize the message shown here.'),
          ),
          if (!_attested)
            const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Text(
                'Required before review',
                style: TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final isPreview = !_deliveryService.canAttemptDirectDelivery;
    return _GuidedStepScroll(
      key: const Key('contact-review-step'),
      artwork: _ReviewPortraitStack(recipients: _selectedRecipients),
      eyebrow: 'READY TO SEND',
      accent: CivicPalette.purple,
      title: 'Review and submit',
      description: isPreview
          ? 'Confirm the message and offices below. The one-submit workflow is ready, but congressional API credentials are placeholders, so this preview will not transmit anything.'
          : 'Confirm the message and offices below. One submission sends the same message to every selected office.',
      bottomPadding: 36,
      children: [
        if (_districtNotice != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CivicPalette.warningTint,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: CivicPalette.warningLine),
            ),
            child: Text(
              _districtNotice!,
              style: const TextStyle(color: Color(0xFF9A3412), height: 1.35),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _VerificationSummary(
          addressProof: _addressProof,
          emailProof: _emailProof,
          attested: _attested,
        ),
        const SizedBox(height: 14),
        _ReviewCard(
          topic: _topic,
          subject: _subjectController.text.trim(),
          message: _messageController.text.trim(),
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          address: _addressController.text.trim(),
          onCopySubject: () =>
              _copy(_subjectController.text.trim(), 'Subject copied'),
          onCopyMessage: () =>
              _copy(_messageController.text.trim(), 'Message copied'),
        ),
        const SizedBox(height: 18),
        _buildSubmissionCard(),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () => setState(() => _step = 0),
          icon: const Icon(CivicIcons.edit),
          label: const Text('Edit message'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: _navy,
            shape: const StadiumBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: CivicPalette.surface,
        border: Border(top: BorderSide(color: CivicPalette.border)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Row(
            children: [
              if (_step > 0) ...[
                TextButton.icon(
                  onPressed: _goToPreviousStep,
                  icon: const Icon(CivicIcons.back),
                  label: const Text('Back'),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: FilledButton(
                  key: const Key('contact-continue-button'),
                  onPressed: _resolvingDistrict ? null : _continue,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: _step == 0
                        ? CivicPalette.teal
                        : CivicPalette.actionBlue,
                    shape: const StadiumBorder(),
                  ),
                  child: _resolvingDistrict
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _step == 0
                                  ? CivicIcons.forward
                                  : CivicIcons.review,
                            ),
                            const SizedBox(width: 9),
                            Text(_step == 0 ? 'Continue' : 'Review message'),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _continue() async {
    if (_step == 0) {
      if ((_composeKey.currentState?.validate() ?? false) &&
          _selectedRecipients.isNotEmpty) {
        setState(() => _step = 1);
      }
      return;
    }
    if ((_detailsKey.currentState?.validate() ?? false) && _attested) {
      FocusManager.instance.primaryFocus?.unfocus();
      final emailVerified = await _ensureEmailVerified();
      if (!emailVerified || !mounted) return;
      await _resolveHouseRecipient();
      if (!mounted) return;
      setState(() => _step = 2);
    }
  }

  Future<bool> _ensureEmailVerified() async {
    final email = _emailController.text.trim();
    final existing = _emailProof;
    if (existing != null && existing.matches(email)) return true;

    try {
      final challenge = await _verificationGateway.startEmailVerification(
        email,
      );
      if (!mounted) return false;
      final proof = await showDialog<EmailVerificationProof>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _EmailVerificationDialog(
          gateway: _verificationGateway,
          challenge: challenge,
        ),
      );
      if (proof == null || !mounted) return false;
      setState(() => _emailProof = proof);
      return true;
    } on ContactCongressVerificationException catch (error) {
      if (mounted) _showVerificationError(error.message);
      return false;
    }
  }

  void _showVerificationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _resolveHouseRecipient() async {
    if (widget.houseCandidates.isEmpty || _resolvedHouseRecipient != null) {
      return;
    }

    final address = _parseAddress(_addressController.text);
    if (address == null) {
      setState(() {
        _districtNotice =
            'We could not check your House district. Your senators are still available below.';
      });
      return;
    }

    setState(() => _resolvingDistrict = true);
    try {
      final result = widget.districtLookup != null
          ? await widget.districtLookup!(address)
          : await CongressionalDistrictService().lookup(address);
      if (!mounted) return;
      if (result.status != CongressionalDistrictLookupStatus.matched ||
          result.match?.stateAbbreviation != address.state) {
        setState(() {
          _districtNotice =
              result.status == CongressionalDistrictLookupStatus.ambiguous
              ? 'The address matched more than one House district, so we did not guess. Your senators are still available below.'
              : 'We could not match this address to a House district. Your senators are still available below.';
        });
        return;
      }

      final matches = widget.houseCandidates
          .where(
            (member) => member.districtNumber == result.match!.districtNumber,
          )
          .toList();
      if (matches.length != 1) {
        setState(() {
          _districtNotice =
              'We could not safely identify one House representative, so we did not guess. Your senators are still available below.';
        });
        return;
      }

      final member = matches.single;
      final url = member.contactUrl ?? member.website;
      if (url == null || url.isEmpty) {
        setState(() {
          _districtNotice =
              'Your House district was matched, but its official contact link is unavailable. Your senators are still available below.';
        });
        return;
      }
      setState(() {
        _resolvedHouseRecipient = ContactCongressRecipient(
          name: member.name,
          role: 'U.S. Representative',
          officialUrl: url,
          bioguideId: member.bioguideId,
          photoAsset: member.photoLocalPath == null
              ? null
              : 'assets/img/${member.photoLocalPath}',
          chamber: CongressionalChamber.house,
        );
        _selectedRecipientKeys.add(_recipientKey(_resolvedHouseRecipient!));
        _districtNotice =
            '${member.name} was added after matching your House district.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _districtNotice =
            'District matching is temporarily unavailable. Your senators are still available below.';
      });
    } finally {
      if (mounted) setState(() => _resolvingDistrict = false);
    }
  }

  String _recipientKey(ContactCongressRecipient recipient) =>
      recipient.bioguideId ?? '${recipient.chamber.name}:${recipient.name}';

  Widget _buildSubmissionCard() {
    final isPreview = !_deliveryService.canAttemptDirectDelivery;
    return Card(
      key: const Key('direct-delivery-card'),
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isPreview ? CivicPalette.purpleTint : CivicPalette.tealTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: isPreview ? CivicPalette.purpleLine : CivicPalette.tealLine,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _deliveryResult == null
                  ? 'Submit once to every office'
                  : isPreview
                  ? 'Submission preview complete'
                  : 'Submission results',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: _navy,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              isPreview
                  ? 'Preview mode: House CWC and Senate SCWC are not connected. Nothing will be sent to Congress.'
                  : 'We will report each office separately. “Accepted” means accepted by the chamber for routing, not read by staff.',
              key: isPreview ? const Key('direct-delivery-placeholder') : null,
              style: const TextStyle(color: Color(0xFF475569), height: 1.35),
            ),
            if (_deliveryResult == null) ...[
              const SizedBox(height: 14),
              for (final recipient in _selectedRecipients)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(
                        CivicIcons.success,
                        size: 19,
                        color: Color(0xFF047857),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${recipient.name} • ${recipient.chamber == CongressionalChamber.house ? 'House CWC' : 'Senate SCWC'}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 12),
            if (_deliveryResult == null)
              FilledButton.icon(
                key: const Key('direct-delivery-submit'),
                onPressed: _submittingDirect ? null : _submitDirect,
                icon: _submittingDirect
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(isPreview ? CivicIcons.review : CivicIcons.send),
                label: Text(
                  _submittingDirect
                      ? 'Checking…'
                      : isPreview
                      ? 'Preview submission'
                      : 'Submit message to ${_selectedRecipients.length} ${_selectedRecipients.length == 1 ? 'office' : 'offices'}',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: isPreview
                      ? CivicPalette.purple
                      : CivicPalette.teal,
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                ),
              )
            else ...[
              if (_deliveryResult!.wasDuplicate)
                const Text(
                  'This request was already submitted. Showing the original results.',
                  key: Key('direct-delivery-duplicate'),
                  style: TextStyle(color: Color(0xFF475569)),
                ),
              for (final office in _deliveryResult!.offices)
                _DeliveryResultRow(result: office),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submitDirect() async {
    setState(() => _submittingDirect = true);
    CongressionalDeliveryRequest? request;
    try {
      final emailProof = _emailProof;
      if (emailProof == null ||
          !emailProof.matches(_emailController.text) ||
          _addressProof.isExpired ||
          _attestedAt == null) {
        throw const ContactCongressVerificationException(
          'A verification expired. Return to your details and verify again.',
        );
      }
      final recipients = [
        for (final recipient in _selectedRecipients)
          CongressionalDeliveryRecipient(
            name: recipient.name,
            chamber: recipient.chamber,
            officialUrl: recipient.officialUrl,
            bioguideId: recipient.bioguideId,
          ),
      ];
      final humanProof = await _verificationGateway.verifyHumanChallenge(
        action: 'contact_congress_send',
      );
      final authorization = await _verificationGateway.authorizeSend(
        CongressionalSendAuthorizationRequest(
          addressProof: _addressProof,
          emailProof: emailProof,
          humanProof: humanProof,
          email: _emailController.text.trim(),
          address: _addressController.text.trim(),
          recipients: recipients,
          topic: _topic,
          subject: _subjectController.text.trim(),
          message: _messageController.text.trim(),
          attestationVersion: 'contact-congress-v1',
          attestedAt: _attestedAt!,
        ),
      );
      request = CongressionalDeliveryRequest(
        idempotencyKey: authorization.idempotencyKey,
        constituent: CongressionalConstituent(
          fullName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          address: _addressController.text.trim(),
          state: widget.stateName,
        ),
        topic: _topic,
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
        recipients: recipients,
        authorizedAt: authorization.issuedAt,
        sendAuthorizationToken: authorization.token,
        sendAuthorizationExpiresAt: authorization.expiresAt,
      );
      final result = await _deliveryService.submit(request);
      if (!mounted) return;
      setState(() => _deliveryResult = result);
    } on ContactCongressVerificationException catch (error) {
      if (!mounted) return;
      _showVerificationError(error.message);
    } catch (_) {
      if (!mounted) return;
      if (request == null) {
        _showVerificationError(
          'Verification could not be completed. Nothing was sent.',
        );
        return;
      }
      final failedRequest = request;
      setState(() {
        _deliveryResult = CongressionalDeliveryResult(
          idempotencyKey: failedRequest.idempotencyKey,
          offices: [
            for (final recipient in failedRequest.recipients)
              CongressionalOfficeDeliveryResult(
                recipient: recipient,
                status: CongressionalDeliveryStatus.failed,
                message:
                    'Delivery could not be confirmed. Nothing will be reported as accepted.',
              ),
          ],
        );
      });
    } finally {
      if (mounted) setState(() => _submittingDirect = false);
    }
  }

  CongressionalDistrictAddress? _parseAddress(String value) {
    final match = RegExp(
      r'^\s*(.+?),\s*([^,]+),\s*([A-Za-z]{2})\s+(\d{5})(?:-\d{4})?\s*$',
    ).firstMatch(value);
    if (match == null) return null;
    return CongressionalDistrictAddress(
      street: match.group(1)!,
      city: match.group(2)!,
      state: match.group(3)!.toUpperCase(),
      zip: match.group(4)!,
    );
  }

  Future<void> _copy(String value, String confirmation) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(confirmation)));
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'This field is required' : null;

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

class _EmailVerificationStatus extends StatelessWidget {
  const _EmailVerificationStatus({
    required this.verified,
    required this.preview,
  });

  final bool verified;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('email-verification-status'),
      children: [
        Icon(
          verified ? CivicIcons.success : CivicIcons.privacy,
          size: 17,
          color: verified ? CivicPalette.green : CivicPalette.actionBlue,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            verified
                ? preview
                      ? 'Email confirmed for this development preview.'
                      : 'Email confirmed.'
                : 'You’ll confirm this email before review. The draft will stay here.',
            style: TextStyle(
              color: verified ? CivicPalette.green : CivicPalette.subtleInk,
              fontSize: 12,
              fontWeight: verified ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _VerificationSummary extends StatelessWidget {
  const _VerificationSummary({
    required this.addressProof,
    required this.emailProof,
    required this.attested,
  });

  final CongressionalAddressProof addressProof;
  final EmailVerificationProof? emailProof;
  final bool attested;

  @override
  Widget build(BuildContext context) {
    final preview =
        addressProof.mode == ContactCongressVerificationMode.preview;
    return Container(
      key: const Key('verification-summary'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CivicPalette.blueTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ready checks',
            style: TextStyle(
              color: CivicPalette.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _VerificationSummaryRow(
            text:
                'Address matched to district ${addressProof.stateAbbreviation}-${addressProof.districtCode}',
          ),
          _VerificationSummaryRow(
            text: emailProof == null
                ? 'Email confirmation missing'
                : preview
                ? 'Email confirmed in development preview'
                : 'Email confirmed',
            success: emailProof != null,
          ),
          _VerificationSummaryRow(
            text: attested
                ? 'Residency and message authorization confirmed'
                : 'Attestation missing',
            success: attested,
          ),
          const SizedBox(height: 5),
          Text(
            preview
                ? 'The human check and five-minute send authorization will also run in development preview when you continue.'
                : 'A quiet human check and five-minute send authorization run only when you press Send.',
            style: const TextStyle(
              color: CivicPalette.subtleInk,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationSummaryRow extends StatelessWidget {
  const _VerificationSummaryRow({required this.text, this.success = true});

  final String text;
  final bool success;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(
            success ? CivicIcons.success : CivicIcons.warning,
            color: success ? CivicPalette.green : const Color(0xFF9A3412),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _EmailVerificationDialog extends StatefulWidget {
  const _EmailVerificationDialog({
    required this.gateway,
    required this.challenge,
  });

  final ContactCongressVerificationGateway gateway;
  final EmailVerificationChallenge challenge;

  @override
  State<_EmailVerificationDialog> createState() =>
      _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends State<_EmailVerificationDialog> {
  final _codeController = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewCode = widget.challenge.previewCode;
    return AlertDialog(
      title: const Text('Confirm your email'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.challenge.mode == ContactCongressVerificationMode.preview
                  ? 'Development preview: no email was sent. Enter the preview code below to test the complete flow.'
                  : 'Enter the six-digit code sent to ${widget.challenge.maskedEmail}. Your draft is safe while you verify.',
              style: const TextStyle(height: 1.4),
            ),
            if (previewCode != null) ...[
              const SizedBox(height: 12),
              Container(
                key: const Key('preview-email-code'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CivicPalette.purpleTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Preview code: $previewCode',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: CivicPalette.purple,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              key: const Key('email-verification-code-field'),
              controller: _codeController,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Six-digit code',
                errorText: _error,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onSubmitted: (_) => _confirm(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.of(context).pop(),
          child: const Text('Back'),
        ),
        FilledButton(
          key: const Key('confirm-email-code-button'),
          onPressed: _checking ? null : _confirm,
          child: Text(_checking ? 'Checking…' : 'Confirm email'),
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    if (_codeController.text.trim().length != 6) {
      setState(() => _error = 'Enter all six digits');
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final proof = await widget.gateway.confirmEmailVerification(
        challenge: widget.challenge,
        code: _codeController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(proof);
    } on ContactCongressVerificationException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }
}

class _GuidedStepScroll extends StatelessWidget {
  const _GuidedStepScroll({
    super.key,
    required this.artwork,
    required this.eyebrow,
    required this.accent,
    required this.title,
    required this.description,
    required this.children,
    this.bottomPadding = 104,
  });

  final Widget artwork;
  final String eyebrow;
  final Color accent;
  final String title;
  final String description;
  final List<Widget> children;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPadding),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                artwork,
                const SizedBox(height: 24),
                Text(
                  eyebrow,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: CivicPalette.navy,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: CivicPalette.mutedInk,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                ...children,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ContactStepArtwork extends StatelessWidget {
  const _ContactStepArtwork({
    required this.icon,
    required this.accent,
    required this.tint,
    required this.secondary,
  });

  final IconData icon;
  final Color accent;
  final Color tint;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Illustration for this step',
      child: SizedBox(
        height: 156,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: ColoredBox(
            color: tint,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 38,
                  top: 24,
                  child: _ArtworkBubble(
                    size: 54,
                    color: secondary,
                    icon: CivicIcons.congress,
                  ),
                ),
                Positioned(
                  right: 48,
                  bottom: 22,
                  child: _ArtworkBubble(
                    size: 62,
                    color: CivicPalette.purpleLine,
                    icon: CivicIcons.delegation,
                  ),
                ),
                Positioned(
                  right: 30,
                  top: 22,
                  child: Container(
                    width: 48,
                    height: 18,
                    decoration: BoxDecoration(
                      color: secondary,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x260F172A),
                        blurRadius: 20,
                        offset: Offset(0, 9),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: Colors.white, size: 34, fill: 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtworkBubble extends StatelessWidget {
  const _ArtworkBubble({
    required this.size,
    required this.color,
    required this.icon,
  });

  final double size;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, color: CivicPalette.navy, size: size * 0.42),
    );
  }
}

class _ReviewPortraitStack extends StatelessWidget {
  const _ReviewPortraitStack({required this.recipients});

  final List<ContactCongressRecipient> recipients;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Selected congressional offices',
      child: SizedBox(
        height: 112,
        child: Center(
          child: SizedBox(
            width: 72 + ((recipients.length - 1).clamp(0, 4) * 46),
            child: Stack(
              children: [
                for (var index = 0; index < recipients.length; index++)
                  Positioned(
                    left: index * 46,
                    top: index.isOdd ? 14 : 0,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: CivicPalette.canvas,
                          width: 5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1F0F172A),
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: _ContactRecipientAvatar(
                        recipient: recipients[index],
                        size: 76,
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

class _ContactRecipientAvatar extends StatelessWidget {
  const _ContactRecipientAvatar({required this.recipient, this.size = 44});

  final ContactCongressRecipient recipient;
  final double size;

  Widget _fallback() {
    final initials = recipient.name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    return ColoredBox(
      color: recipient.chamber == CongressionalChamber.house
          ? CivicPalette.tealLine
          : CivicPalette.blueLine,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: CivicPalette.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photo = recipient.photoAsset;
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: photo == null || photo.isEmpty
            ? _fallback()
            : Image.asset(
                photo,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(),
              ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int currentStep;

  const _ProgressHeader({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const labels = ['Write', 'Your details', 'Review & submit'];
    const icons = [CivicIcons.write, CivicIcons.verified, CivicIcons.review];
    const accents = [
      CivicPalette.teal,
      CivicPalette.actionBlue,
      CivicPalette.purple,
    ];
    const tints = [
      CivicPalette.tealTint,
      CivicPalette.blueTint,
      CivicPalette.purpleTint,
    ];
    final overallStep = currentStep + 2;
    return Semantics(
      label: 'Step $overallStep of 4: ${labels[currentStep]}',
      child: Container(
        color: CivicPalette.surface,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: tints[currentStep],
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icons[currentStep],
                    color: accents[currentStep],
                    size: 21,
                    fill: currentStep == 2 ? 1 : 0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        labels[currentStep],
                        style: const TextStyle(
                          color: CivicPalette.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Step $overallStep of 4',
                        style: const TextStyle(
                          color: CivicPalette.subtleInk,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _ContactProgressDots(current: overallStep),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactProgressDots extends StatelessWidget {
  const _ContactProgressDots({required this.current});

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

class _RecipientsCard extends StatelessWidget {
  final List<ContactCongressRecipient> recipients;
  final Set<String> selectedRecipientKeys;
  final String Function(ContactCongressRecipient recipient) recipientKey;
  final void Function(ContactCongressRecipient recipient, bool selected)
  onChanged;

  const _RecipientsCard({
    required this.recipients,
    required this.selectedRecipientKeys,
    required this.recipientKey,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CivicPalette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: CivicPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${selectedRecipientKeys.length} ${selectedRecipientKeys.length == 1 ? 'office' : 'offices'} selected',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          for (final recipient in recipients)
            CheckboxListTile(
              key: Key('contact-recipient-${recipientKey(recipient)}'),
              value: selectedRecipientKeys.contains(recipientKey(recipient)),
              onChanged: (value) => onChanged(recipient, value ?? false),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              secondary: _ContactRecipientAvatar(recipient: recipient),
              title: Text('${recipient.name} • ${recipient.role}'),
              activeColor: CivicPalette.teal,
            ),
        ],
      ),
    );
  }
}

class _DeliveryResultRow extends StatelessWidget {
  const _DeliveryResultRow({required this.result});

  final CongressionalOfficeDeliveryResult result;

  @override
  Widget build(BuildContext context) {
    final accepted =
        result.status == CongressionalDeliveryStatus.acceptedForRouting;
    final delivered = result.status == CongressionalDeliveryStatus.delivered;
    final color = accepted || delivered
        ? const Color(0xFF047857)
        : const Color(0xFF9A3412);
    final label = switch (result.status) {
      CongressionalDeliveryStatus.acceptedForRouting => 'Accepted for routing',
      CongressionalDeliveryStatus.delivered => 'Delivered',
      CongressionalDeliveryStatus.needsUserAction => 'Needs attention',
      CongressionalDeliveryStatus.unavailable => 'Not sent',
      CongressionalDeliveryStatus.rejected => 'Not accepted',
      CongressionalDeliveryStatus.failed => 'Could not confirm',
    };

    return Semantics(
      label: '${result.recipient.name}: $label. ${result.message}',
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              accepted || delivered ? CivicIcons.success : CivicIcons.error,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${result.recipient.name} • $label',
                    style: TextStyle(fontWeight: FontWeight.w700, color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result.message,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String topic;
  final String subject;
  final String message;
  final String name;
  final String email;
  final String address;
  final VoidCallback onCopySubject;
  final VoidCallback onCopyMessage;

  const _ReviewCard({
    required this.topic,
    required this.subject,
    required this.message,
    required this.name,
    required this.email,
    required this.address,
    required this.onCopySubject,
    required this.onCopyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shadowColor: const Color(0x1F0F172A),
      margin: EdgeInsets.zero,
      color: CivicPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: CivicPalette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              topic,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    subject,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy subject',
                  onPressed: onCopySubject,
                  icon: const Icon(CivicIcons.copy),
                ),
              ],
            ),
            const Divider(),
            Text(message, style: const TextStyle(height: 1.45)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onCopyMessage,
              icon: const Icon(CivicIcons.copy),
              label: const Text('Copy message'),
              style: FilledButton.styleFrom(
                backgroundColor: CivicPalette.teal,
                shape: const StadiumBorder(),
              ),
            ),
            const Divider(height: 28),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(email),
            Text(address),
          ],
        ),
      ),
    );
  }
}
