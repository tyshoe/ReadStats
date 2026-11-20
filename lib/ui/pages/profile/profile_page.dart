import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:read_stats/data/models/goal.dart';
import 'package:read_stats/data/models/preset_avatar.dart';
import 'package:read_stats/data/repositories/goal_repository.dart';
import 'package:read_stats/data/services/analytics_service.dart';
import 'package:read_stats/data/services/avatar_service.dart';
import 'package:read_stats/data/utils/money.dart';
import 'package:read_stats/domain/badges.dart';
import 'package:read_stats/domain/reading_activity.dart';
import 'package:read_stats/domain/reading_stats.dart';
import 'package:read_stats/domain/seasons.dart';
import 'package:read_stats/ui/pages/profile/achievements_page.dart';
import 'package:read_stats/ui/pages/profile/activity_page.dart';
import 'package:read_stats/ui/pages/profile/spending_page.dart';
import 'package:read_stats/ui/pages/profile/widgets/achievements_card.dart';
import 'package:read_stats/ui/pages/profile/widgets/preset_avatar_option.dart';
import 'package:read_stats/ui/pages/profile/widgets/profile_hero_stat.dart';
import 'package:read_stats/ui/settings_view_model.dart';
import 'package:read_stats/ui/widgets/image_editor_page.dart';

/// The reader's identity surface: avatar + name, lifetime headline stats, and
/// a tiered achievements wall. Deliberately the "headline" to the Statistics
/// page's "story" — cumulative and personal, not analytical.
class ProfilePage extends StatefulWidget {
  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> sessions;
  final SettingsViewModel settingsViewModel;
  final GoalRepository goalRepository;

  /// Open the full Settings page (gear in the app bar).
  final void Function(BuildContext context) onOpenSettings;

  const ProfilePage({
    super.key,
    required this.books,
    required this.sessions,
    required this.settingsViewModel,
    required this.goalRepository,
    required this.onOpenSettings,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();

  /// Warm the goals cache at app startup so the first Profile visit paints with
  /// goals already present, instead of loading them in after navigation.
  static Future<void> preloadGoals(GoalRepository repo) async {
    _ProfilePageState._cachedGoals = await _ProfilePageState._fetchGoals(repo);
  }
}

class _GoalProgress {
  final Goal goal;
  final PeriodProgress progress;

  /// Every target the goal has had — the activity feed judges past periods
  /// against the target they had at the time.
  final List<GoalTargetChange> targets;
  const _GoalProgress(this.goal, this.progress, this.targets);
}

class _ProfilePageState extends State<ProfilePage> {
  // The Profile tab is rebuilt on every nav switch, so cache the async-resolved
  // avatar and goals across instances. Seeding from these caches lets a revisit
  // paint complete on the first frame and just refresh in the background,
  // instead of popping the avatar/goals in after the page has appeared.
  static String? _cachedAvatarPath;
  static List<_GoalProgress>? _cachedGoals;

  late ReadingStats _stats;
  late List<ActivityEntry> _activity;
  String? _avatarPath = _cachedAvatarPath;
  List<_GoalProgress> _goals = _cachedGoals ?? [];
  bool _goalsLoaded = _cachedGoals != null;
  final ScrollController _scrollController = ScrollController();
  double _appBarOpacity = 0;

  @override
  void initState() {
    super.initState();
    _stats = ReadingStats.from(books: widget.books, sessions: widget.sessions);
    _rebuildActivity();
    widget.settingsViewModel.profileAvatarNotifier.addListener(_resolveAvatar);
    _scrollController.addListener(_onScroll);
    _resolveAvatar();
    _loadGoals();
  }

  void _onScroll() {
    // Fade the app bar background in as the header gradient scrolls up behind
    // it, so the title and settings icon stay legible without snapping. Starts
    // once the avatar nears the bar and reaches full opacity shortly after.
    const fadeStart = 40.0;
    const fadeEnd = 160.0;
    final offset = _scrollController.offset;
    final raw = ((offset - fadeStart) / (fadeEnd - fadeStart)).clamp(0.0, 1.0);
    // Quantize so setState fires in steps instead of every scroll pixel.
    final stepped = (raw * 20).round() / 20;
    if (stepped != _appBarOpacity) {
      setState(() => _appBarOpacity = stepped);
    }
  }

  static Future<List<_GoalProgress>> _fetchGoals(GoalRepository repo) async {
    final goals = await repo.getGoals();
    final result = <_GoalProgress>[];
    for (final goal in goals) {
      final progress = await repo.getCurrentProgress(goal);
      final targets = await repo.getTargetChanges(goal);
      result.add(_GoalProgress(goal, progress, targets));
    }
    return result;
  }

  Future<void> _loadGoals() async {
    final result = await _fetchGoals(widget.goalRepository);
    _cachedGoals = result;
    if (mounted) {
      setState(() {
        _goals = result;
        _goalsLoaded = true;
        _rebuildActivity();
      });
    }
  }

  void _rebuildActivity() {
    _activity = ReadingActivity.build(
      books: widget.books,
      sessions: widget.sessions,
      goals: [for (final g in _goals) (g.goal, g.targets)],
    );
  }

  @override
  void didUpdateWidget(ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.books != widget.books ||
        oldWidget.sessions != widget.sessions) {
      _stats =
          ReadingStats.from(books: widget.books, sessions: widget.sessions);
      _rebuildActivity();
      // Goal progress is derived from the same books/sessions, so it has to be
      // refetched when they change or the cards show stale numbers.
      _loadGoals();
    }
  }

  @override
  void dispose() {
    widget.settingsViewModel.profileAvatarNotifier
        .removeListener(_resolveAvatar);
    _scrollController.dispose();
    super.dispose();
  }

  // Only photo avatars need resolving; presets are drawn straight from assets.
  // Always rebuilds, so switching between two presets repaints too.
  Future<void> _resolveAvatar() async {
    final value = widget.settingsViewModel.profileAvatarNotifier.value;
    final path = (value == null || AvatarService.isPreset(value))
        ? null
        : await AvatarService.resolve(value);
    _cachedAvatarPath = path;
    if (mounted) setState(() => _avatarPath = path);
  }

  // ── Editing ────────────────────────────────────────────────────────────────

  Future<void> _editName() async {
    final controller = TextEditingController(
      text: widget.settingsViewModel.profileNameNotifier.value,
    );
    final accent = widget.settingsViewModel.accentColorNotifier.value;

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 30,
          decoration: const InputDecoration(
            hintText: 'Reader name',
            counterText: '',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: TextButton.styleFrom(foregroundColor: accent),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (name != null) {
      await widget.settingsViewModel.setProfileName(name);
    }
  }

  Future<void> _editAvatar() async {
    final accent = widget.settingsViewModel.accentColorNotifier.value;
    final notifier = widget.settingsViewModel.profileAvatarNotifier;

    // Preset picks apply in place and leave the sheet open (the check mark moves
    // to the new one); the rows below the divider pop with an action instead.
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final sheetColor = theme.bottomSheetTheme.backgroundColor ??
            theme.colorScheme.surfaceContainerLow;
        return SafeArea(
          child: ValueListenableBuilder<String?>(
            valueListenable: notifier,
            builder: (ctx, current, _) {
              final hasAvatar = current != null;
              final hasPhoto = hasAvatar && !AvatarService.isPreset(current);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Choose an avatar',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        for (final preset in presetAvatars)
                          Expanded(
                            child: PresetAvatarOption(
                              preset: preset,
                              selected:
                                  current == AvatarService.presetValue(preset.id),
                              accent: accent,
                              sheetColor: sheetColor,
                              onTap: () => _applyPreset(preset),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 17,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  if (hasPhoto)
                    ListTile(
                      leading: const Icon(Icons.crop_rotate),
                      title: const Text('Adjust photo'),
                      onTap: () => Navigator.pop(ctx, 'adjust'),
                    ),
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: Text(hasPhoto ? 'Change photo' : 'Choose photo'),
                    onTap: () => Navigator.pop(ctx, 'choose'),
                  ),
                  if (hasAvatar)
                    ListTile(
                      leading: Icon(
                        Icons.delete,
                        color: theme.colorScheme.error,
                      ),
                      title: Text(
                        'Remove avatar',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                      onTap: () => Navigator.pop(ctx, 'remove'),
                    ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        );
      },
    );

    if (action == 'choose') {
      final picked = await AvatarService.pickImage();
      if (picked == null) return;
      await _cropAndStore(picked, keepAsOriginal: true);
    } else if (action == 'adjust') {
      // Re-crop from the full photo when we still have it, so repeated edits
      // don't crop into an already-cropped result.
      var source = await AvatarService.originalFile();
      if (source == null) {
        final current = widget.settingsViewModel.profileAvatarNotifier.value;
        if (current == null) return;
        source = File(await AvatarService.resolve(current));
        if (!await source.exists()) return;
      }
      await _cropAndStore(source, keepAsOriginal: false);
    } else if (action == 'remove') {
      final previous = widget.settingsViewModel.profileAvatarNotifier.value;
      await widget.settingsViewModel.setProfileAvatar(null);
      await AvatarService.delete(previous);
      await AvatarService.deleteOriginal();
    }
  }

  /// Switch to a bundled avatar, discarding any photo it replaces so the
  /// stored copies don't linger.
  Future<void> _applyPreset(PresetAvatar preset) async {
    final previous = widget.settingsViewModel.profileAvatarNotifier.value;
    final value = AvatarService.presetValue(preset.id);
    if (previous == value) return;
    await widget.settingsViewModel.setProfileAvatar(value);
    await AvatarService.delete(previous);
    await AvatarService.deleteOriginal();
  }

  /// Run [source] through the crop editor and, if the user keeps the result,
  /// make it the new avatar. [keepAsOriginal] stores [source] as the pre-crop
  /// image for later re-adjustment.
  Future<void> _cropAndStore(File source,
      {required bool keepAsOriginal}) async {
    if (!mounted) return;
    final edited = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => ImageEditorPage(
          imageFile: source,
          aspectRatio: 1,
          circleMask: true,
          title: 'Adjust photo',
          outputPrefix: 'edited_avatar',
        ),
      ),
    );
    if (edited == null) return;
    if (keepAsOriginal) await AvatarService.saveOriginal(source.path);
    final previous = widget.settingsViewModel.profileAvatarNotifier.value;
    final filename = await AvatarService.save(edited.path);
    await widget.settingsViewModel.setProfileAvatar(filename);
    await AvatarService.delete(previous);
  }

  /// Opens the ladder for a medal — a seasonal one against [season].
  void _showMedal(ReadingGoal goal, [Season? season]) {
    showMedalDetail(
      context,
      goal: goal,
      season: season,
      books: widget.books,
      sessions: widget.sessions,
      accent: widget.settingsViewModel.accentColorNotifier.value,
    );
  }

  void _openAchievements(Color accent) {
    AnalyticsService.instance.screen('achievements');
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AchievementsPage(
        books: widget.books,
        sessions: widget.sessions,
        accent: accent,
      ),
    ));
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.settingsViewModel.accentColorNotifier.value;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor:
            theme.scaffoldBackgroundColor.withValues(alpha: _appBarOpacity),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 40,
        shape: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withAlpha((128 * _appBarOpacity).round()),
            width: .25,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => widget.onOpenSettings(context),
          ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _buildHeader(theme, accent),
          const SizedBox(height: 8),
          _buildHeroStats(theme),
          _buildSpending(theme, accent),
          _buildGoals(theme, accent),
          AchievementsCard(
            books: widget.books,
            sessions: widget.sessions,
            stats: _stats,
            activity: _activity,
            accent: accent,
            onOpen: () => _openAchievements(accent),
            onMedalTap: _showMedal,
          ),
          _buildActivity(theme, accent),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Color accent) {
    final muted = theme.colorScheme.onSurfaceVariant;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 48, 16, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withAlpha(60),
            accent.withAlpha(14),
            Colors.transparent,
          ],
          stops: const [0, 0.6, 1],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          _buildAvatar(theme, accent),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: widget.settingsViewModel.profileNameNotifier,
                  builder: (context, name, _) {
                    final hasName = name.trim().isNotEmpty;
                    return InkWell(
                      onTap: _editName,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                hasName ? name : 'Add your name',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: hasName
                                      ? theme.colorScheme.onSurface
                                      : muted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.edit, size: 16, color: muted),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_stories_outlined, size: 13, color: muted),
                    const SizedBox(width: 6),
                    Text(
                      _readingSinceLabel(),
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme, Color accent) {
    final name = widget.settingsViewModel.profileNameNotifier.value;
    final initials = _initials(name);
    final hasImage = _avatarPath != null;
    final preset = AvatarService.preset(
      widget.settingsViewModel.profileAvatarNotifier.value,
    );

    return GestureDetector(
      onTap: _editAvatar,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Presets skip CircleAvatar: they already carry their own background
          // and outline ring, so a tinted circle behind them would halo.
          if (preset != null)
            SizedBox(
              width: 84,
              height: 84,
              child: SvgPicture.asset(preset.asset),
            )
          else
            CircleAvatar(
              radius: 42,
              backgroundColor: accent.withAlpha(38),
              foregroundImage: hasImage ? FileImage(File(_avatarPath!)) : null,
              onForegroundImageError: hasImage ? (_, _) {} : null,
              child: hasImage
                  ? null
                  : (initials != null
                      ? Text(
                          initials,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : Icon(Icons.person, size: 40, color: accent)),
            ),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                border:
                    Border.all(color: theme.scaffoldBackgroundColor, width: 2),
              ),
              child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStats(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: IntrinsicHeight(
            child: Row(
              children: [
                ProfileHeroStat(label: 'Books', value: _compact(_stats.booksFinished)),
                _heroDivider(theme),
                ProfileHeroStat(label: 'Hours', value: _compact(_stats.totalHours)),
                _heroDivider(theme),
                ProfileHeroStat(
                    label: 'Pages', value: _compact(_stats.totalPagesRead)),
                _heroDivider(theme),
                ProfileHeroStat(
                  label: 'Best streak',
                  value: '${_stats.longestWeekStreak}w',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroDivider(ThemeData theme) => VerticalDivider(
        width: 1,
        thickness: 1,
        indent: 4,
        endIndent: 4,
        color: theme.dividerColor.withAlpha(80),
      );

  /// The way in to the spending page — one row, and only for readers who
  /// turned spending on in Settings. Everyone else never sees money.
  Widget _buildSpending(ThemeData theme, Color accent) {
    final settings = widget.settingsViewModel;
    return ValueListenableBuilder<bool>(
      valueListenable: settings.spendingEnabledNotifier,
      builder: (context, enabled, _) {
        if (!enabled) return const SizedBox.shrink();
        return ValueListenableBuilder<String>(
          valueListenable: settings.currencyNotifier,
          builder: (context, currency, _) {
            var count = 0;
            var spent = 0.0;
            for (final b in widget.books) {
              final paid = b['price_paid'] as num?;
              if (paid == null) continue;
              count++;
              spent += paid;
            }
            final muted = theme.colorScheme.onSurfaceVariant;

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SpendingPage(
                        books: widget.books,
                        sessions: widget.sessions,
                        settingsViewModel: settings,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                    child: Row(
                      children: [
                        Icon(Icons.payments, size: 20, color: accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Spending',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                count == 0
                                    ? 'Add a price to a book to start'
                                    : '${Money.format(spent, currency, whole: true)}'
                                        ' on $count ${count == 1 ? 'book' : 'books'}',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: muted),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: muted),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGoals(ThemeData theme, Color accent) {
    // Hide entirely until loaded to avoid a flash; goal management lives in
    // Tracking — this is a read-only progress mirror.
    if (!_goalsLoaded) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Goals',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_goals.isEmpty)
            Card(
              margin: EdgeInsets.zero,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined,
                        size: 20, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No goals yet — set one in Tracking to track your habit.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              margin: EdgeInsets.zero,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < _goals.length; i++)
                      _buildGoalRow(theme, accent, _goals[i]),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGoalRow(ThemeData theme, Color accent, _GoalProgress gp) {
    final metric = gp.goal.metric;
    final p = gp.progress;
    final met = p.met;
    // When complete, switch to the same green completion color used by the
    // tracking goals so a met goal reads as "done" rather than just accented.
    final completionColor = _completionColor(accent);
    final barColor = met ? completionColor : accent.withAlpha(200);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(_metricIcon(metric), size: 20, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      metric.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      gp.goal.period.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    if (met)
                      Icon(Icons.check_circle, size: 16, color: completionColor),
                    if (met) const SizedBox(width: 4),
                    Text(
                      '${metric.cardDisplay(p.actual)} / ${metric.unitLabel(p.target)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: p.ratio,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(barColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Mirrors the tracking goals' completion color: green normally, with a blue
  // fallback when the accent itself is green-ish so the "complete" state stays
  // visually distinct from the accent.
  Color _completionColor(Color accent) {
    final hue = HSLColor.fromColor(accent).hue;
    if (hue >= 80 && hue <= 170) return const Color(0xFF2196F3);
    return Colors.green.shade600;
  }

  IconData _metricIcon(GoalMetric metric) {
    switch (metric) {
      case GoalMetric.booksFinished:
        return Icons.local_library_rounded;
      case GoalMetric.timeReading:
        return Icons.schedule_rounded;
      case GoalMetric.pagesRead:
        return Icons.menu_book_rounded;
      case GoalMetric.sessions:
        return Icons.event_repeat_rounded;
    }
  }

  static const _recentActivityCount = 5;

  /// The latest few things the reader did; the full feed is a tap away.
  /// Medals are left to the Achievements card above, which shows the latest
  /// of those — the full feed still has them.
  Widget _buildActivity(ThemeData theme, Color accent) {
    if (_activity.isEmpty) return const SizedBox.shrink();
    final recent = _activity
        .where((e) => e.kind != ActivityKind.badge)
        .take(_recentActivityCount)
        .toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recent activity',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_activity.length > recent.length)
                GestureDetector(
                  onTap: () => _openActivity(accent),
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    'See all',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ActivityCard(entries: recent, accent: accent),
        ],
      ),
    );
  }

  void _openActivity(Color accent) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ActivityPage(
        entries: _activity,
        accent: accent,
        onBadgeTap: (e) => _showMedal(e.badge!, e.season),
      ),
    ));
  }

  String _readingSinceLabel() {
    final since = _stats.readingSince;
    if (since == null) return 'Start your reading journey';
    return 'Reading since ${DateFormat('MMM yyyy').format(since)}';
  }

  String? _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return null;
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? null : letters;
  }

  String _compact(int n) => NumberFormat.compact().format(n);
}
