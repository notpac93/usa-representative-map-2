import 'package:flutter/material.dart';

/// A compact profile entry. Contact is available before opening the profile.
class OfficialListTile extends StatelessWidget {
  const OfficialListTile({
    super.key,
    required this.name,
    required this.subtitle,
    required this.onTap,
    this.photoPath,
    this.contactAction,
  });
  final String name, subtitle;
  final String? photoPath;
  final VoidCallback onTap;
  final Widget? contactAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFD9E1EC)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 64,
                  height: 78,
                  child: photoPath == null
                      ? _fallback()
                      : Image.asset(
                          photoPath!.startsWith('assets/')
                              ? photoPath!
                              : 'assets/img/$photoPath',
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          excludeFromSemantics: true,
                          errorBuilder: (_, _, _) => _fallback(),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF102D54),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFF51647B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (contactAction != null)
                contactAction!
              else
                const Icon(Icons.chevron_right, color: Color(0xFF102D54)),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _fallback() => const ColoredBox(
    color: Color(0xFFDBE5F2),
    child: Icon(Icons.person_outline, size: 36, color: Color(0xFF456A99)),
  );
}
