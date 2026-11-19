import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:read_stats/app.dart';
import 'package:read_stats/app_config.dart';
import 'package:read_stats/data/database/database_helper.dart';
import 'package:read_stats/data/repositories/book_repository.dart';
import 'package:read_stats/data/repositories/goal_repository.dart';
import 'package:read_stats/data/repositories/session_repository.dart';
import 'package:read_stats/data/repositories/tag_repository.dart';
import 'package:read_stats/data/services/import_export_service.dart';
import 'package:read_stats/data/services/notification_prefs_store.dart';
import 'package:read_stats/data/services/notification_service.dart';
import 'package:read_stats/data/services/rating_service.dart';
import 'package:read_stats/data/services/reading_timer_service.dart';
import 'package:read_stats/data/services/recap_store.dart';
import 'package:read_stats/ui/settings_view_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await AppConfig.init();
  await RatingService.instance.registerAppStart();

  final dbHelper = DatabaseHelper();
  await dbHelper.database;

  final bookRepository = BookRepository(dbHelper);
  final sessionRepository = SessionRepository(dbHelper);
  final tagRepository = TagRepository(dbHelper);
  final goalRepository = GoalRepository(dbHelper);

  final importExportService = ImportExportService(
    bookRepository: bookRepository,
    sessionRepository: sessionRepository,
    tagRepository: tagRepository,
    goalRepository: goalRepository,
  );

  final themeMode = await SettingsViewModel.loadSavedThemeMode();
  final hasSeenOnboarding = await SettingsViewModel.getHasSeenOnboarding();
  SettingsViewModel.setHasSeenOnboarding();

  final timerService = ReadingTimerService();
  await timerService.restore();

  // Reminders are re-registered on every launch. Alarms don't survive an app
  // update, a force stop, or a timezone change, and none of those tell the app
  // to fix things up — rescheduling at launch covers all of them.
  await NotificationPrefsStore.instance.load();
  // Which monthly recap has already been read, for the mark on the Stats tab.
  await RecapStore.instance.load();
  NotificationService.instance.configure(goalRepository: goalRepository);
  await NotificationService.instance.init();
  // Arms the reminders that need no data. The ones that quote live numbers
  // follow once the first books/sessions load reaches updateData below.
  await NotificationService.instance.rescheduleAll();

  runApp(
    ReadStatsApp(
      themeMode: themeMode,
      bookRepository: bookRepository,
      sessionRepository: sessionRepository,
      tagRepository: tagRepository,
      goalRepository: goalRepository,
      importExportService: importExportService,
      hasSeenOnboarding: hasSeenOnboarding,
      timerService: timerService,
    ),
  );
}
