import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../data/civic_data_provider.dart';
import '../data/bill_models.dart';
import '../data/models.dart';

class PresidentDetailScreen extends StatefulWidget {
  final President? initialPresident;

  const PresidentDetailScreen({super.key, this.initialPresident});

  @override
  State<PresidentDetailScreen> createState() => _PresidentDetailScreenState();
}

class _PresidentDetailScreenState extends State<PresidentDetailScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  final TextEditingController _searchController = TextEditingController();

  President? _selectedPresident;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', '2026', '2025', '2024'
  String _selectedStatusFilter = 'all'; // 'all', 'in-effect', 'revoked', 'amended'
  bool _isLoading = false;
  final Set<String> _expandedOrderIds = <String>{};

  @override
  void initState() {
    super.initState();
    _selectedPresident = widget.initialPresident ??
        CivicDataProvider().getCurrentPresident() ??
        CivicDataProvider.defaultPresidents.first;
    _loadData();
  }

  Future<void> _loadData() async {
    if (_selectedPresident == null && CivicDataProvider().getPresidents().isEmpty) {
      setState(() => _isLoading = true);
    }
    await CivicDataProvider().loadData();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _selectedPresident ??= CivicDataProvider().getCurrentPresident() ??
            (CivicDataProvider().getPresidents().isNotEmpty
                ? CivicDataProvider().getPresidents().first
                : null);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String urlString) async {
    if (urlString.isEmpty) return;
    final uri = Uri.parse(urlString);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        debugPrint("Could not launch $urlString");
      }
    } catch (e) {
      debugPrint("Error launching url: $e");
    }
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final parts = isoDate.split('-');
      if (parts.length == 3) {
        final year = parts[0];
        final month = parts[1].padLeft(2, '0');
        final day = parts[2].padLeft(2, '0');
        return '$month/$day/$year';
      }
      final parsed = DateTime.tryParse(isoDate);
      if (parsed != null) {
        final m = parsed.month.toString().padLeft(2, '0');
        final d = parsed.day.toString().padLeft(2, '0');
        return '$m/$d/${parsed.year}';
      }
    } catch (_) {}
    return isoDate;
  }

  Future<void> _shareCard() async {
    try {
      final image = await _screenshotController.capture(
        delay: const Duration(milliseconds: 10),
      );
      if (image != null) {
        final directory = await getApplicationDocumentsDirectory();
        final imagePath = await File('${directory.path}/president_card.png').create();
        await imagePath.writeAsBytes(image);
        await Share.shareXFiles(
          [XFile(imagePath.path)],
          text: 'Executive Orders & Information for ${_selectedPresident?.name ?? "the President"}',
        );
      }
    } catch (e) {
      debugPrint("Screenshot Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _selectedPresident == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final provider = CivicDataProvider();
    final allPresidents = provider.getPresidents();
    final president = _selectedPresident!;

    // Get executive orders for currently selected president
    final allOrders = provider.getExecutiveOrdersForPresident(president.id);

    // Apply search filter and year filter
    final filteredOrders = allOrders.where((eo) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = eo.title.toLowerCase().contains(q);
        final matchNum = eo.orderNumber.toLowerCase().contains(q);
        final matchCit = eo.citation.toLowerCase().contains(q);
        final matchSummary = eo.summary?.toLowerCase().contains(q) ?? false;
        if (!matchTitle && !matchNum && !matchCit && !matchSummary) {
          return false;
        }
      }

      if (_selectedFilter != 'all') {
        if (!eo.signingDate.startsWith(_selectedFilter)) {
          return false;
        }
      }

      if (_selectedStatusFilter == 'in-effect') {
        if (!eo.isInEffect) return false;
      } else if (_selectedStatusFilter == 'revoked') {
        if (!eo.isRevoked && !eo.isSuperseded) return false;
      } else if (_selectedStatusFilter == 'amended') {
        if (!eo.isAmended) return false;
      }

      return true;
    }).toList();

    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: Text(president.name),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Card',
            onPressed: _shareCard,
          ),
          if (president.website != null)
            IconButton(
              icon: const Icon(Icons.language),
              tooltip: 'Official White House Site',
              onPressed: () => _launchUrl(president.website!),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Administration Switcher if multiple presidents exist
                    if (allPresidents.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: _buildAdministrationSwitcher(allPresidents),
                      ),

                    // Top Hero Section: Profile Card & Constitutional Powers Card
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Screenshot(
                              controller: _screenshotController,
                              child: _buildPresidentProfileCard(president),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: _buildPowersCard(),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          Screenshot(
                            controller: _screenshotController,
                            child: _buildPresidentProfileCard(president),
                          ),
                          const SizedBox(height: 20),
                          _buildPowersCard(),
                        ],
                      ),

                    const SizedBox(height: 36),

                    // THE EXECUTIVE ORDERS SECTION
                    _buildExecutiveOrdersSection(
                      context: context,
                      president: president,
                      orders: filteredOrders,
                      allPresidentOrders: allOrders,
                    ),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdministrationSwitcher(List<President> presidents) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance, size: 18, color: Color(0xFF1E3A8A)),
              const SizedBox(width: 8),
              const Text(
                "Select Presidential Administration:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presidents.map((p) {
              final isSelected = p.id == _selectedPresident?.id;
              final partyTag = p.party.toLowerCase().contains('rep') ? 'R' : 'D';
              return ChoiceChip(
                label: Text(
                  p.current ? "${p.name} (Current)" : "${p.name} ($partyTag)",
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.blueGrey[900],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
                selected: isSelected,
                selectedColor: const Color(0xFF1E3A8A),
                backgroundColor: const Color(0xFFF1F5F9),
                elevation: isSelected ? 2 : 0,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedPresident = p;
                      _selectedFilter = 'all';
                      _selectedStatusFilter = 'all';
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPresidentProfileCard(President president) {
    final partyColor = president.party.toLowerCase().contains('rep')
        ? const Color(0xFFDC2626) // Red
        : const Color(0xFF2563EB); // Blue

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar / Presidential Seal
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: president.photoLocalPath != null
                      ? Image.asset(
                          president.photoLocalPath!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              president.photoUrl != null
                                  ? Image.network(
                                      president.photoUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.account_balance,
                                        color: Colors.white,
                                        size: 44,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.account_balance,
                                      color: Colors.white,
                                      size: 44,
                                    ),
                        )
                      : (president.photoUrl != null
                          ? Image.network(
                              president.photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                Icons.account_balance,
                                color: Colors.white,
                                size: 44,
                              ),
                            )
                          : const Icon(
                              Icons.account_balance,
                              color: Colors.white,
                              size: 44,
                            )),
                ),
              ),
              const SizedBox(width: 20),

              // Title and Badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: partyColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: partyColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            president.party,
                            style: TextStyle(
                              color: partyColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (president.current)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              "Active Term",
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      president.name,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      president.ordinal,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // Metadata Details Grid
          Wrap(
            spacing: 20,
            runSpacing: 12,
            children: [
              _buildMetaItem(
                Icons.calendar_today,
                "Terms in Office",
                president.terms.join(', '),
              ),
              if (president.vicePresident != null)
                _buildMetaItem(
                  Icons.group,
                  "Vice President",
                  president.vicePresident!,
                ),
              if (president.address != null)
                _buildMetaItem(
                  Icons.location_on,
                  "Official Office",
                  president.address!,
                ),
              if (president.phone != null)
                _buildMetaItem(
                  Icons.phone,
                  "Contact",
                  president.phone!,
                ),
            ],
          ),

          if (president.bio != null) ...[
            const SizedBox(height: 16),
            Text(
              president.bio!,
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String label, String value) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey[500]),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey[400], fontWeight: FontWeight.bold),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPowersCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueGrey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.gavel, color: Color(0xFF1E3A8A), size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                "Article II Powers",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPowerBullet("Executive Orders", "Directives issued to federal agencies with the binding force of law."),
          const SizedBox(height: 10),
          _buildPowerBullet("Commander in Chief", "Supreme command over the Army, Navy, Air Force, Marines, and Coast Guard."),
          const SizedBox(height: 10),
          _buildPowerBullet("Federal Appointments", "Appoints Supreme Court Justices, federal judges, ambassadors, and cabinet heads."),
          const SizedBox(height: 10),
          _buildPowerBullet("Legislation & Veto", "Signs acts of Congress into law or exercises presidential veto authority."),
        ],
      ),
    );
  }

  Widget _buildPowerBullet(String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4.0),
          child: Icon(Icons.check_circle_outline, color: Color(0xFF1E3A8A), size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
              children: [
                TextSpan(text: "$title: ", style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExecutiveOrdersSection({
    required BuildContext context,
    required President president,
    required List<ExecutiveOrderRecord> orders,
    required List<ExecutiveOrderRecord> allPresidentOrders,
  }) {
    final totalOrdersCount = allPresidentOrders.length;
    final availableYears = <String>{};
    for (final order in allPresidentOrders) {
      if (order.signingDate.length >= 4) {
        availableYears.add(order.signingDate.substring(0, 4));
      }
    }
    final sortedYears = availableYears.toList()..sort((a, b) => b.compareTo(a));
    final displayYears = sortedYears.isNotEmpty
        ? sortedYears
        : (president.current ? ['2026', '2025'] : <String>[]);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title and Source Attribution Banner
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.description, color: Color(0xFF1E3A8A), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          "Executive Orders",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A8A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "$totalOrdersCount Orders",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Directives signed by ${president.name} with force of law.",
                      style: TextStyle(fontSize: 14, color: Colors.blueGrey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Official Government Source Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified, color: Color(0xFF0284C7), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                      children: [
                        TextSpan(
                          text: "Official Government Source: ",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        TextSpan(
                          text: "Directly fetched from the Office of the Federal Register (National Archives & Records Administration) and published via GPO GovInfo.",
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Executive Order Legal Effect & Disposition Explainer Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.gavel, color: Color(0xFF15803D), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 12, color: Color(0xFF14532D)),
                      children: [
                        TextSpan(
                          text: "Legal Effect & Disposition Tracking: ",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                        ),
                        TextSpan(
                          text: "Executive orders carry binding administrative force of law unless revoked or superseded by a subsequent President, overridden by Congress, or enjoined by federal courts. Live disposition notes are provided directly by the Federal Register API.",
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Search & Filter Controls
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search executive orders by title, order number (e.g. 14423), or subject...",
                    prefixIcon: const Icon(Icons.search, color: Colors.blueGrey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Dynamic Year Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip("All Orders", 'all'),
                for (final yr in displayYears) ...[
                  const SizedBox(width: 8),
                  _buildFilterChip("$yr Orders", yr),
                ],
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Legal Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusFilterChip("All Statuses", 'all', Icons.tune),
                const SizedBox(width: 8),
                _buildStatusFilterChip("In Effect", 'in-effect', Icons.check_circle),
                const SizedBox(width: 8),
                _buildStatusFilterChip("Revoked", 'revoked', Icons.cancel),
                const SizedBox(width: 8),
                _buildStatusFilterChip("Amended", 'amended', Icons.edit_note),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // List of Executive Orders
          if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.blueGrey[300]),
                    const SizedBox(height: 12),
                    Text(
                      _searchQuery.isNotEmpty
                          ? "No executive orders match '$_searchQuery'."
                          : "No executive orders found for the selected filter.",
                      style: TextStyle(fontSize: 15, color: Colors.blueGrey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: orders.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final eo = orders[index];
                return _buildExecutiveOrderCard(eo);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF334155),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF0F172A),
      backgroundColor: const Color(0xFFF1F5F9),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = value;
          });
        }
      },
    );
  }

  Widget _buildStatusFilterChip(String label, String value, IconData icon) {
    final isSelected = _selectedStatusFilter == value;
    Color activeColor = const Color(0xFF0F172A);
    if (value == 'in-effect') activeColor = const Color(0xFF15803D);
    if (value == 'revoked') activeColor = const Color(0xFFB91C1C);
    if (value == 'amended') activeColor = const Color(0xFFB45309);

    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected ? Colors.white : activeColor,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF334155),
        ),
      ),
      selected: isSelected,
      selectedColor: activeColor,
      backgroundColor: const Color(0xFFF1F5F9),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedStatusFilter = value;
          });
        }
      },
    );
  }

  Widget _buildStatusBadge(ExecutiveOrderRecord eo) {
    Color bg;
    Color border;
    Color text;
    IconData icon;
    String label;

    if (eo.isRevoked) {
      bg = const Color(0xFFFEE2E2);
      border = const Color(0xFFFCA5A5);
      text = const Color(0xFFB91C1C);
      icon = Icons.cancel;
      label = "Revoked";
    } else if (eo.isSuperseded) {
      bg = const Color(0xFFFEF3C7);
      border = const Color(0xFFFCD34D);
      text = const Color(0xFFB45309);
      icon = Icons.history;
      label = "Superseded";
    } else if (eo.isAmended) {
      bg = const Color(0xFFE0F2FE);
      border = const Color(0xFFBAE6FD);
      text = const Color(0xFF0369A1);
      icon = Icons.edit_note;
      label = "Amended";
    } else {
      bg = const Color(0xFFDCFCE7);
      border = const Color(0xFF86EFAC);
      text = const Color(0xFF15803D);
      icon = Icons.check_circle;
      label = "In Effect";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalStatusAlert(ExecutiveOrderRecord eo) {
    Color bg;
    Color border;
    Color titleColor;
    Color bodyColor;
    IconData icon;
    String title;
    String body;

    if (eo.isRevoked) {
      bg = const Color(0xFFFEF2F2);
      border = const Color(0xFFFECACA);
      titleColor = const Color(0xFF991B1B);
      bodyColor = const Color(0xFF7F1D1D);
      icon = Icons.warning_amber_rounded;
      title = "Legal Status: Revoked (No Longer in Effect)";
      body = eo.statusDetails ?? eo.dispositionNotes ?? "This order has been officially revoked and is no longer binding upon federal agencies.";
    } else if (eo.isSuperseded) {
      bg = const Color(0xFFFFFBEB);
      border = const Color(0xFFFDE68A);
      titleColor = const Color(0xFF92400E);
      bodyColor = const Color(0xFF78350F);
      icon = Icons.history_edu;
      title = "Legal Status: Superseded by Later Action";
      body = eo.statusDetails ?? eo.dispositionNotes ?? "This executive order has been superseded by a subsequent presidential action.";
    } else if (eo.isAmended) {
      bg = const Color(0xFFF0F9FF);
      border = const Color(0xFFBAE6FD);
      titleColor = const Color(0xFF075985);
      bodyColor = const Color(0xFF0C4A6E);
      icon = Icons.edit_note;
      title = "Legal Status: Amended";
      body = eo.statusDetails ?? eo.dispositionNotes ?? "This executive order remains operative as amended by subsequent executive action.";
    } else {
      bg = const Color(0xFFF0FDF4);
      border = const Color(0xFFBBF7D0);
      titleColor = const Color(0xFF166534);
      bodyColor = const Color(0xFF14532D);
      icon = Icons.verified_user_outlined;
      title = "Legal Status: In Effect (Active Force of Law)";
      body = eo.statusDetails ?? "Active and legally binding across federal departments and agencies under Article II. Not revoked or superseded.";
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: titleColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: titleColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: border),
                      ),
                      child: Text(
                        "NARA / Federal Register",
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    color: bodyColor,
                    height: 1.3,
                  ),
                ),
                if (eo.dispositionNotes != null && !body.contains(eo.dispositionNotes!)) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Disposition Note: ${eo.dispositionNotes!.replaceAll('\r', '').replaceAll('\n', '; ')}",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: bodyColor.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetaTag(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          children: [
            TextSpan(
              text: "$label: ",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveOrderCard(ExecutiveOrderRecord eo) {
    final isExpanded = _expandedOrderIds.contains(eo.id);
    final formattedSigningDate = _formatDate(eo.signingDate);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Badges Row: EO Number, Status & Citation on left, Date on right edge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left badges
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // EO Number
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "E.O. ${eo.orderNumber}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),

                    // Official Status Badge
                    _buildStatusBadge(eo),

                    // Citation
                    if (eo.citation.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          eo.citation,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Date on right edge with MM/DD/YYYY format
              if (formattedSigningDate.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blueGrey.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event, size: 13, color: Colors.blueGrey.shade700),
                      const SizedBox(width: 5),
                      Text(
                        formattedSigningDate,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.blueGrey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Order Title
          Text(
            eo.title,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              height: 1.3,
            ),
          ),

          const SizedBox(height: 8),

          // Dedicated Legal Status Alert Section
          _buildLegalStatusAlert(eo),

          const SizedBox(height: 8),

          // Clickable Expand / Collapse Summary toggle
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedOrderIds.remove(eo.id);
                } else {
                  _expandedOrderIds.add(eo.id);
                }
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isExpanded ? const Color(0xFFEFF6FF) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isExpanded ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: const Color(0xFF1E3A8A),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isExpanded ? "Collapse Summary" : "Read Order Summary",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable Readable Summary Panel
          if (isExpanded) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.menu_book_outlined, size: 16, color: Color(0xFF1E3A8A)),
                      const SizedBox(width: 6),
                      const Text(
                        "Official Summary & Scope",
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 10),
                  Text(
                    (eo.summary != null && eo.summary!.trim().isNotEmpty)
                        ? eo.summary!
                        : "Executive Order ${eo.orderNumber} directs federal departments and agencies regarding \"${eo.title}\". Promulgated by President ${eo.president} pursuant to presidential authority under Article II of the United States Constitution.",
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.55,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildSummaryMetaTag("President", eo.president),
                      if (formattedSigningDate.isNotEmpty)
                        _buildSummaryMetaTag("Signed", formattedSigningDate),
                      if (eo.publicationDate.isNotEmpty)
                        _buildSummaryMetaTag("Published", _formatDate(eo.publicationDate)),
                      if (eo.citation.isNotEmpty)
                        _buildSummaryMetaTag("Citation", eo.citation),
                      _buildSummaryMetaTag("Authority", "U.S. Const. Art. II"),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Action Buttons: Federal Register link & GovInfo PDF link
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (eo.url.isNotEmpty)
                OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 15),
                  label: const Text("Federal Register Doc"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => _launchUrl(eo.url),
                ),

              if (eo.pdfUrl.isNotEmpty)
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf, size: 15),
                  label: const Text("Official PDF (GovInfo)"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    elevation: 0,
                  ),
                  onPressed: () => _launchUrl(eo.pdfUrl),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
