import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:read_stats/data/models/preset_avatar.dart';

class PresetAvatarOption extends StatelessWidget {
  final PresetAvatar preset;
  final bool selected;
  final Color accent;

  /// The sheet's own background, painted as the gap between the avatar and the
  /// accent ring so the ring reads as a separate stroke.
  final Color sheetColor;
  final VoidCallback onTap;

  const PresetAvatarOption({
    super.key,
    required this.preset,
    required this.selected,
    required this.accent,
    required this.sheetColor,
    required this.onTap,
  });

  // 54 + 3 gap + 2 ring = 64 wide, which fits five across a narrow phone.
  static const double _size = 54;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: sheetColor,
                    border: Border.all(
                      color: selected ? accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: SizedBox(
                    width: _size,
                    height: _size,
                    child: SvgPicture.asset(preset.asset),
                  ),
                ),
                if (selected)
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: sheetColor, width: 2),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              preset.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: selected
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
