import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';
import '/viewmodels/SettingsViewModel.dart';

/// Interactive preview of the app's bottom tab bar, shown in Settings.
///
/// It renders the real [StylishBottomBar] using the user's current style and
/// accent (kept in sync with `main.dart`). The segmented control changes the
/// bar's *style*; tapping a tab in the bar sets the *startup tab*. Both
/// navigation settings are configured live, in place, rather than through two
/// separate text pickers — the user sees exactly what they're choosing.
class NavPreview extends StatelessWidget {
  final SettingsViewModel settingsViewModel;

  const NavPreview({super.key, required this.settingsViewModel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AnimatedBuilder(
      animation: Listenable.merge([
        settingsViewModel.navStyleNotifier,
        settingsViewModel.defaultTabNotifier,
        settingsViewModel.accentColorNotifier,
      ]),
      builder: (context, _) {
        final style = settingsViewModel.navStyleNotifier.value;
        final startupTab = settingsViewModel.defaultTabNotifier.value;
        final accent = settingsViewModel.accentColorNotifier.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Style selector — drives the bar's look directly below it.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<IconStyle>(
                  segments: const [
                    ButtonSegment(
                        value: IconStyle.Default, label: Text('Standard')),
                    ButtonSegment(
                        value: IconStyle.simple, label: Text('Simple')),
                    ButtonSegment(
                        value: IconStyle.animated, label: Text('Animated')),
                  ],
                  selected: {style},
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  onSelectionChanged: (selection) =>
                      settingsViewModel.setNavStyle(selection.first),
                ),
              ),
            ),
            // Hint sits above the bar it refers to.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'Tap a tab to choose where the app opens.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 4),
            // The real bar, flush with the card's rounded bottom edge.
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: StylishBottomBar(
                items: _buildItems(accent),
                currentIndex: startupTab,
                onTap: (index) => settingsViewModel.setDefaultTab(index),
                option: AnimatedBarOptions(
                  iconSize: 28,
                  iconStyle: style,
                  opacity: 0.3,
                ),
                backgroundColor: Colors.transparent,
              ),
            ),
          ],
        );
      },
    );
  }

  List<BottomBarItem> _buildItems(Color accent) {
    return [
      BottomBarItem(
        icon: const Icon(FluentIcons.library_16_filled),
        selectedIcon: Icon(FluentIcons.library_16_filled, color: accent),
        title: const Text('Library'),
        unSelectedColor: Colors.grey,
        selectedColor: accent,
      ),
      BottomBarItem(
        icon: const Icon(FluentIcons.calendar_16_filled),
        selectedIcon: Icon(FluentIcons.calendar_16_filled, color: accent),
        title: const Text('Tracking'),
        unSelectedColor: Colors.grey,
        selectedColor: accent,
      ),
      BottomBarItem(
        icon: const Icon(FluentIcons.data_pie_16_filled),
        selectedIcon: Icon(FluentIcons.data_pie_16_filled, color: accent),
        title: const Text('Stats'),
        unSelectedColor: Colors.grey,
        selectedColor: accent,
      ),
      BottomBarItem(
        icon: const Icon(FluentIcons.person_16_filled),
        selectedIcon: Icon(FluentIcons.person_16_filled, color: accent),
        title: const Text('Profile'),
        unSelectedColor: Colors.grey,
        selectedColor: accent,
      ),
    ];
  }
}
