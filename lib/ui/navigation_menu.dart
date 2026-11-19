import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:read_stats/data/repositories/book_repository.dart';
import 'package:read_stats/data/repositories/goal_repository.dart';
import 'package:read_stats/data/repositories/session_repository.dart';
import 'package:read_stats/data/repositories/tag_repository.dart';
import 'package:read_stats/data/services/import_export_service.dart';
import 'package:read_stats/data/services/reading_timer_service.dart';
import 'package:read_stats/ui/pages/library/library_page.dart';
import 'package:read_stats/ui/pages/profile/profile_page.dart';
import 'package:read_stats/ui/pages/sessions/sessions_page.dart';
import 'package:read_stats/ui/pages/settings/settings_page.dart';
import 'package:read_stats/ui/pages/statistics/statistics_page.dart';
import 'package:read_stats/ui/settings_view_model.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';

/// The bottom-navigation shell holding the four main tabs.
class NavigationMenu extends StatefulWidget {
  final Function(ThemeMode) toggleTheme;
  final ThemeMode themeMode;
  final Function(Map<String, dynamic>) addBook;
  final Function() refreshBooks;
  final Function() refreshSessions;
  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> sessions;
  final BookRepository bookRepository;
  final SessionRepository sessionRepository;
  final TagRepository tagRepository;
  final GoalRepository goalRepository;
  final ImportExportService importExportService;
  final SettingsViewModel settingsViewModel;
  final ReadingTimerService timerService;

  const NavigationMenu({
    super.key,
    required this.toggleTheme,
    required this.themeMode,
    required this.books,
    required this.addBook,
    required this.refreshBooks,
    required this.refreshSessions,
    required this.sessions,
    required this.bookRepository,
    required this.sessionRepository,
    required this.tagRepository,
    required this.goalRepository,
    required this.importExportService,
    required this.settingsViewModel,
    required this.timerService,
  });

  @override
  State<NavigationMenu> createState() => _NavigationMenuState();
}

class _NavigationMenuState extends State<NavigationMenu> {
  late int _activeTabIndex;

  @override
  void initState() {
    super.initState();
    _activeTabIndex = widget.settingsViewModel.defaultTabNotifier.value;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: widget.settingsViewModel.accentColorNotifier,
      builder: (context, accentColor, child) {
        return ValueListenableBuilder<IconStyle>(
          valueListenable: widget.settingsViewModel.navStyleNotifier,
          builder: (context, tabVisibility, child) {
            return Scaffold(
              body: _getPage(_activeTabIndex),
              bottomNavigationBar: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).dividerColor.withAlpha(128),
                      width: .25,
                    ),
                  ),
                ),
                child: StylishBottomBar(
                  items: _buildBottomBarItems(accentColor),
                  currentIndex: _activeTabIndex,
                  onTap: (index) {
                    setState(() {
                      _activeTabIndex = index;
                    });
                  },
                  option: AnimatedBarOptions(
                    iconSize: 28,
                    iconStyle: widget.settingsViewModel.navStyleNotifier.value,
                    opacity: 0.3,
                  ),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<BottomBarItem> _buildBottomBarItems(Color accentColor) {
    return [
      BottomBarItem(
        icon: Icon(FluentIcons.library_16_filled),
        selectedIcon: Icon(FluentIcons.library_16_filled, color: accentColor),
        title: Text('Library'),
        unSelectedColor: Colors.grey,
        selectedColor: accentColor,
      ),
      BottomBarItem(
        icon: Icon(FluentIcons.calendar_16_filled),
        selectedIcon: Icon(FluentIcons.calendar_16_filled, color: accentColor),
        title: Text('Tracking'),
        unSelectedColor: Colors.grey,
        selectedColor: accentColor,
      ),
      BottomBarItem(
        icon: Icon(FluentIcons.data_pie_16_filled),
        selectedIcon: Icon(FluentIcons.data_pie_16_filled, color: accentColor),
        title: Text('Stats'),
        unSelectedColor: Colors.grey,
        selectedColor: accentColor,
      ),
      BottomBarItem(
        icon: Icon(FluentIcons.person_16_filled),
        selectedIcon: Icon(FluentIcons.person_16_filled, color: accentColor),
        title: Text('Profile'),
        unSelectedColor: Colors.grey,
        selectedColor: accentColor,
      ),
    ];
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return LibraryPage(
          books: widget.books,
          refreshBooks: widget.refreshBooks,
          refreshSessions: widget.refreshSessions,
          settingsViewModel: widget.settingsViewModel,
          sessionRepository: widget.sessionRepository,
          bookRepository: widget.bookRepository,
        );
      case 1:
        return SessionsPage(
          books: widget.books,
          sessions: widget.sessions,
          refreshSessions: widget.refreshSessions,
          refreshBooks: widget.refreshBooks,
          settingsViewModel: widget.settingsViewModel,
          sessionRepository: widget.sessionRepository,
          bookRepository: widget.bookRepository,
          goalRepository: widget.goalRepository,
          timerService: widget.timerService,
        );
      case 2:
        return StatisticsPage(
          bookRepository: widget.bookRepository,
          sessionRepository: widget.sessionRepository,
          settingsViewModel: widget.settingsViewModel,
          books: widget.books,
          sessions: widget.sessions,
        );
      case 3:
      default:
        return ProfilePage(
          books: widget.books,
          sessions: widget.sessions,
          settingsViewModel: widget.settingsViewModel,
          goalRepository: widget.goalRepository,
          onOpenSettings: (ctx) => Navigator.of(ctx).push(
            MaterialPageRoute(
              builder: (_) => SettingsPage(
                toggleTheme: widget.toggleTheme,
                themeMode: widget.themeMode,
                importExportService: widget.importExportService,
                refreshBooks: widget.refreshBooks,
                refreshSessions: widget.refreshSessions,
                settingsViewModel: widget.settingsViewModel,
                timerService: widget.timerService,
              ),
            ),
          ),
        );
    }
  }
}
