import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/data_provider.dart';
import '../design/civic_icons.dart';
import '../widgets/civic_glass.dart';
import '../utils/search_handler.dart';
import 'local_detail_screen.dart';

/// One dedicated location-search step, separate from the landing choices.
class FindRepsScreen extends StatefulWidget {
  const FindRepsScreen({super.key, this.imageBackground = false});
  final bool imageBackground;
  @override
  State<FindRepsScreen> createState() => _FindRepsScreenState();
}

class _FindRepsScreenState extends State<FindRepsScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<SearchResult> _results = [];
  bool _searching = false;
  String? _error;
  Animation<double>? _routeAnimation;
  bool _initialFocusRequested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (_routeAnimation != animation) {
      _routeAnimation?.removeStatusListener(_onRouteStatus);
      _routeAnimation = animation;
      animation?.addStatusListener(_onRouteStatus);
    }
    if (animation == null || animation.status == AnimationStatus.completed) {
      _requestInitialFocus();
    }
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _requestInitialFocus();
  }

  void _requestInitialFocus() {
    if (_initialFocusRequested) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _initialFocusRequested ||
          !(ModalRoute.of(context)?.isCurrent ?? true)) {
        return;
      }
      _initialFocusRequested = true;
      _focusNode.requestFocus();
    });
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty || _searching) return;
    _focusNode.unfocus();
    setState(() {
      _searching = true;
      _error = null;
      _results = [];
    });
    try {
      final results = await SearchHandler().search(
        query,
        context.read<MapDataProvider>(),
      );
      if (!mounted) return;
      setState(() {
        _results = results
            .where(
              (r) =>
                  r.type == SearchResultType.address ||
                  r.type == SearchResultType.zipCode ||
                  r.type == SearchResultType.city ||
                  r.type == SearchResultType.county ||
                  r.type == SearchResultType.state,
            )
            .toList();
        if (_results.isEmpty) {
          _error = 'No locations found. Try another ZIP code or address.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Search could not finish. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: widget.imageBackground ? Colors.transparent : civicCanvas,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: civicNavy,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, bounds) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: bounds.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CivicGlassPanel(
                        key: const ValueKey('location-search-panel'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Find My Reps',
                              key: Key('finder-page-title'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: civicNavy,
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _search(),
                              decoration: const InputDecoration(
                                hintText: 'ZIP code or location',
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: Icon(CivicIcons.search),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF102D54),
                                minimumSize: const Size(0, 52),
                              ),
                              onPressed: _searching ? null : _search,
                              child: Text(_searching ? 'Searching…' : 'Search'),
                            ),
                          ],
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: CivicGlassPanel(child: Text(_error!)),
                        ),
                      const SizedBox(height: 20),
                      for (final result in _results)
                        Card(
                          color: Colors.white,
                          child: ListTile(
                            leading: const Icon(CivicIcons.address),
                            title: Text(result.title),
                            subtitle: Text(result.subtitle),
                            trailing: const Icon(CivicIcons.next),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    LocalDetailScreen(searchResult: result),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
