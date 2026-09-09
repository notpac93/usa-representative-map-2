import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/data_provider.dart';
import '../utils/search_handler.dart';
import '../main.dart';
import 'state_detail_screen.dart';
import 'local_detail_screen.dart';
import 'president_detail_screen.dart';
import 'congress_screen.dart';
import 'supreme_court_screen.dart';
import '../data/civic_data_provider.dart';
import '../widgets/executive_section_card.dart';
import '../widgets/congress_scroll_section.dart';
import '../widgets/judicial_section_card.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  @override
  void initState() {
    super.initState();
    CivicDataProvider().loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MapDataProvider>().loadAllData();
    });
  }

  void _navigateToMap() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (ctx) => const MapScreen()));
  }

  void _handleSelection(SearchResult result) {
    if (result.type == SearchResultType.president) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => const PresidentDetailScreen(),
        ),
      );
    } else if (result.type == SearchResultType.congress) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => const CongressScreen(),
        ),
      );
    } else if (result.type == SearchResultType.supremeCourt) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => const SupremeCourtScreen(),
        ),
      );
    } else if (result.type == SearchResultType.state) {
      if (result.stateId != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => StateDetailScreen(stateId: result.stateId!),
          ),
        );
      }
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => LocalDetailScreen(searchResult: result),
        ),
      );
    }
  }

  Widget _buildSearchCenter(MapDataProvider provider, {bool isWidescreen = false, double maxWidth = 520}) {
    final searchBoxMaxWidth = isWidescreen ? maxWidth : 640.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/img/logo.png',
          height: isWidescreen ? 68 : 72,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 12),
        Text(
          'Find Your Representatives',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: isWidescreen ? 23 : 24,
            color: const Color(0xFF0F172A),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Container(
          constraints: BoxConstraints(maxWidth: searchBoxMaxWidth),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.how_to_vote, size: 14, color: Color(0xFF1D4ED8)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Prioritizing Upcoming 2026 Elections • Candidates, Ballot Measures & Reps',
                  style: const TextStyle(
                    color: Color(0xFF1E40AF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          constraints: BoxConstraints(maxWidth: searchBoxMaxWidth),
          child: Autocomplete<SearchResult>(
            optionsBuilder: (TextEditingValue textEditingValue) async {
              if (textEditingValue.text.trim().toLowerCase() == 'map') {
                return const Iterable<SearchResult>.empty();
              }
              if (textEditingValue.text.isEmpty) {
                return const Iterable<SearchResult>.empty();
              }
              return await SearchHandler().search(
                textEditingValue.text,
                provider,
              );
            },
            displayStringForOption: (SearchResult option) => option.title,
            onSelected: (SearchResult selection) {
              _handleSelection(selection);
            },
            fieldViewBuilder:
                (context, controller, focusNode, onEditingComplete) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                onEditingComplete: () {
                  if (controller.text.trim().toLowerCase() == 'map') {
                    _navigateToMap();
                  }
                  onEditingComplete();
                },
                decoration: InputDecoration(
                  hintText: 'Enter your home address, ZIP code, city, or state...',
                  hintStyle: TextStyle(
                    fontSize: 13.5,
                    color: Colors.blueGrey.shade400,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF1E3A8A),
                  ),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            controller.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blueGrey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blueGrey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onSubmitted: (value) async {
                  final query = value.trim();
                  if (query.isEmpty) return;
                  if (query.toLowerCase() == 'map') {
                    _navigateToMap();
                    return;
                  }
                  final results = await SearchHandler().search(query, provider);
                  if (results.isNotEmpty) {
                    controller.text = results.first.title;
                    _handleSelection(results.first);
                  }
                },
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: searchBoxMaxWidth,
                    constraints: const BoxConstraints(maxHeight: 340),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blueGrey.shade200),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: options.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.blueGrey.shade100),
                      itemBuilder: (BuildContext context, int index) {
                        final option = options.elementAt(index);
                        return ListTile(
                          title: Text(
                            option.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                          ),
                          subtitle: Text(
                            option.subtitle,
                            style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 12.5),
                          ),
                          leading: Icon(
                            option.type == SearchResultType.address
                                ? Icons.home
                                : option.type == SearchResultType.president
                                    ? Icons.account_balance
                                    : option.type == SearchResultType.congress
                                        ? Icons.domain
                                        : option.type == SearchResultType.supremeCourt
                                            ? Icons.balance
                                            : option.type == SearchResultType.state
                                                ? Icons.map
                                                : option.type == SearchResultType.city
                                                    ? Icons.location_city
                                                    : option.type == SearchResultType.county
                                                        ? Icons.landscape
                                                        : Icons.mark_as_unread,
                            color: option.type == SearchResultType.address
                                ? const Color(0xFF0284C7)
                                : option.type == SearchResultType.president
                                    ? const Color(0xFF1E3A8A)
                                    : option.type == SearchResultType.congress
                                        ? const Color(0xFF0F766E)
                                        : option.type == SearchResultType.supremeCourt
                                            ? const Color(0xFF3B0764)
                                            : option.type == SearchResultType.state
                                                ? const Color(0xFF4F46E5)
                                                : option.type == SearchResultType.city
                                                    ? const Color(0xFF0D9488)
                                                    : const Color(0xFF2563EB),
                          ),
                          trailing: const Icon(Icons.arrow_forward, size: 16, color: Colors.blueGrey),
                          onTap: () {
                            onSelected(option);
                          },
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _navigateToMap,
              icon: const Icon(Icons.map, size: 16, color: Color(0xFF1E3A8A)),
              label: const Text('Explore National Map'),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1E3A8A),
                side: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const PresidentDetailScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.account_balance, size: 16, color: Color(0xFF1E3A8A)),
              label: const Text('Executive Branch'),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1E3A8A),
                side: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const CongressScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.groups, size: 16, color: Color(0xFF1E3A8A)),
              label: const Text('Legislative Branch'),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1E3A8A),
                side: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const SupremeCourtScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.balance, size: 16, color: Color(0xFF1E3A8A)),
              label: const Text('Judicial Branch'),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1E3A8A),
                side: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MapDataProvider>();

    if (!provider.isLoading) {
      SearchHandler().loadData();
      CivicDataProvider().loadData();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Desktop and iPad view: width >= 950px
          final isWidescreen = constraints.maxWidth >= 950;

          if (!isWidescreen) {
            // Mobile and compact tablet view (centered clean search)
            return Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: _buildSearchCenter(provider, isWidescreen: false),
                ),
              ),
            );
          }

          // Edge-Docked 3-Branch Federal Dashboard (Desktop & iPad):
          // 1. Executive is snapped to the LEFT edge (left: 0, top: 0)
          // 2. Supreme Court / Judicial is snapped to the RIGHT edge (right: 0, top: 0)
          // 3. Congress is snapped to the BOTTOM edge (bottom: 0, left: 0, right: 0)
          // 4. Center Search is placed between the left and right panels, above the bottom ribbon.
          final leftWidth = constraints.maxWidth < 1150 ? 270.0 : 300.0;
          final rightWidth = constraints.maxWidth < 1150 ? 300.0 : 330.0;
          const congressHeight = 112.0;
          final centerMaxWidth = (constraints.maxWidth - leftWidth - rightWidth - 36).clamp(380.0, 560.0);

          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              children: [
                // Center Search Hub (Positioned between left & right panels, above bottom ribbon)
                Positioned.fill(
                  left: leftWidth,
                  right: rightWidth,
                  bottom: congressHeight,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                      child: _buildSearchCenter(
                        provider,
                        isWidescreen: true,
                        maxWidth: centerMaxWidth,
                      ),
                    ),
                  ),
                ),

                // Left Edge Docked Section: Executive Branch (President & VP)
                Positioned(
                  left: 0,
                  top: 0,
                  width: leftWidth,
                  child: ExecutiveSectionCard(
                    isDocked: true,
                    width: leftWidth,
                  ),
                ),

                // Right Edge Docked Section: Judicial Branch / Supreme Court (3x3 Grid)
                Positioned(
                  right: 0,
                  top: 0,
                  width: rightWidth,
                  child: JudicialSectionCard(
                    isDocked: true,
                    width: rightWidth,
                  ),
                ),

                // Bottom Edge Docked Section: Congress Auto-Scroll Ribbon
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: congressHeight,
                  child: const CongressScrollSection(
                    height: congressHeight,
                    isDocked: true,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
