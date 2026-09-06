import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/data_provider.dart';
import '../data/models.dart';
import '../screens/lawmaker_detail_screen.dart';

class SupremeCourtWidget extends StatefulWidget {
  const SupremeCourtWidget({super.key});

  @override
  State<SupremeCourtWidget> createState() => _SupremeCourtWidgetState();
}

class _SupremeCourtWidgetState extends State<SupremeCourtWidget> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MapDataProvider>();
    final justices = provider.supremeCourt;

    if (justices == null || justices.isEmpty) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.blueGrey,
                  backgroundImage: AssetImage(
                    'assets/img/supremecourt/group_photo.jpg',
                  ),
                ),
                if (!_expanded) ...[
                  const SizedBox(width: 8),
                  const Text(
                    "Supreme Court",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
          if (_expanded)
            ...justices.map((justice) {
              return Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LawmakerDetailScreen(
                          lawmaker: justice,
                          role: "Supreme Court Justice",
                          stateId: "national",
                        ),
                      ),
                    );
                  },
                  child: Tooltip(
                    message: "${justice.name}\n${justice.title}",
                    child: CircleAvatar(
                      backgroundImage: justice.photoLocalPath != null
                          ? AssetImage('assets/img/${justice.photoLocalPath}')
                          : null,
                      backgroundColor: const Color(0xFFE9E0FF),
                      child: justice.photoLocalPath == null
                          ? const Icon(
                              Icons.person,
                              color: Color(0xFF3B2E58),
                              size: 16,
                            )
                          : null,
                    ),
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}
