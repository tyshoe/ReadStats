import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/data/models/goal.dart';
import '/data/repositories/goal_repository.dart';
import '/data/services/avatar_service.dart';
import '/viewmodels/SettingsViewModel.dart';
import 'badges.dart';
import 'reading_stats.dart';

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
  const _GoalProgress(this.goal, this.progress);
}

class _ProfilePageState extends State<ProfilePage> {
  // The Profile tab is rebuilt on every nav switch, so cache the async-resolved
  // avatar and goals across instances. Seeding from these caches lets a revisit
  // paint complete on the first frame and just refresh in the background,
  // instead of popping the avatar/goals in after the page has appeared.
  static String? _cachedAvatarPath;
  static List<_GoalProgress>? _cachedGoals;

  late ReadingStats _stats;
  String? _avatarPath = _cachedAvatarPath;
  List<_GoalProgress> _goals = _cachedGoals ?? [];
  bool _goalsLoaded = _cachedGoals != null;
  final ScrollController _scrollController = ScrollController();
  double _appBarOpacity = 0;

  @override
  void initState() {
    super.initState();
    _stats = ReadingStats.from(books: widget.books, sessions: widget.sessions);
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
      result.add(_GoalProgress(goal, progress));
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
      });
    }
  }

  @override
  void didUpdateWidget(ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.books != widget.books ||
        oldWidget.sessions != widget.sessions) {
      _stats =
          ReadingStats.from(books: widget.books, sessions: widget.sessions);
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

  Future<void> _resolveAvatar() async {
    final filename = widget.settingsViewModel.profileAvatarNotifier.value;
    if (filename == null) {
      _cachedAvatarPath = null;
      if (mounted) setState(() => _avatarPath = null);
      return;
    }
    final path = await AvatarService.resolve(filename);
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
    final hasAvatar =
        widget.settingsViewModel.profileAvatarNotifier.value != null;

    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(hasAvatar ? 'Change photo' : 'Choose photo'),
              onTap: () => Navigator.pop(ctx, 'choose'),
            ),
            if (hasAvatar)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(ctx).colorScheme.error,
                ),
                title: Text(
                  'Remove photo',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (action == 'choose') {
      final picked = await AvatarService.pickImage();
      if (picked == null) return;
      final previous = widget.settingsViewModel.profileAvatarNotifier.value;
      final filename = await AvatarService.save(picked.path);
      await widget.settingsViewModel.setProfileAvatar(filename);
      await AvatarService.delete(previous);
    } else if (action == 'remove') {
      final previous = widget.settingsViewModel.profileAvatarNotifier.value;
      await widget.settingsViewModel.setProfileAvatar(null);
      await AvatarService.delete(previous);
    }
  }

  void _showGoalDetail(ReadingGoal goal) {
    final accent = widget.settingsViewModel.accentColorNotifier.value;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _GoalDetailSheet(goal: goal, stats: _stats, accent: accent),
    );
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
          _buildThisYear(theme, accent),
          _buildGoals(theme, accent),
          _buildAchievements(theme, accent),
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

    return GestureDetector(
      onTap: _editAvatar,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
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
                _HeroStat(label: 'Books', value: _compact(_stats.booksFinished)),
                _heroDivider(theme),
                _HeroStat(label: 'Hours', value: _compact(_stats.totalHours)),
                _heroDivider(theme),
                _HeroStat(
                    label: 'Pages', value: _compact(_stats.totalPagesRead)),
                _heroDivider(theme),
                _HeroStat(
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

  // Compact accent strip under the lifetime hero card: "This year" momentum at
  // a glance, deliberately lighter weight so it reads as a footnote to the
  // cumulative numbers above rather than a competing twin card.
  Widget _buildThisYear(ThemeData theme, Color accent) {
    final books = _stats.booksThisYear;
    final summary = '${_compact(books)} ${books == 1 ? 'book' : 'books'}'
        ' · ${_compact(_stats.hoursThisYear)}h'
        ' · ${_compact(_stats.pagesThisYear)} pages';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          Icon(Icons.calendar_today_rounded, size: 14, color: accent),
          const SizedBox(width: 8),
          Text(
            'This year',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              summary,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
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

  Widget _buildAchievements(ThemeData theme, Color accent) {
    final earned = earnedMilestones(_stats);
    final total = totalMilestones;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Achievements',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '$earned of $total',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 8,
              childAspectRatio: 0.92,
            ),
            itemCount: kGoals.length,
            itemBuilder: (context, index) {
              final goal = kGoals[index];
              return _GoalTile(
                goal: goal,
                stats: _stats,
                accent: accent,
                onTap: () => _showGoalDetail(goal),
              );
            },
          ),
        ],
      ),
    );
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

// ── Hero stat (big number + label) ────────────────────────────────────────────

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Goal tile (progress ring + tiered medal) ──────────────────────────────────

class _GoalTile extends StatelessWidget {
  final ReadingGoal goal;
  final ReadingStats stats;
  final Color accent;
  final VoidCallback onTap;

  const _GoalTile({
    required this.goal,
    required this.stats,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tier = goal.highestTier(stats);
    final started = tier != null;
    final tierColor = started ? badgeTierColor(tier.tier) : null;
    final muted = theme.colorScheme.onSurfaceVariant;

    // Unearned badges deliberately recede so they don't compete with the
    // metallic tier colors (silver especially): a faint neutral track, a barely
    // tinted well, and a dimmed icon read as "locked", not as a medal.
    final ringValue = goal.isComplete(stats) ? 1.0 : goal.progress(stats);
    final ringTrack = started
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surfaceContainerHighest.withAlpha(110);
    final ringColor = started ? tierColor! : muted.withAlpha(45);
    final wellColor = started
        ? tierColor!.withAlpha(38)
        : theme.colorScheme.surfaceContainerHighest.withAlpha(80);
    final iconColor = started ? tierColor! : muted.withAlpha(75);
    final labelColor =
        started ? theme.colorScheme.onSurface : muted.withAlpha(130);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 54,
              height: 54,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: CircularProgressIndicator(
                      value: ringValue,
                      strokeWidth: 3,
                      backgroundColor: ringTrack,
                      valueColor: AlwaysStoppedAnimation(ringColor),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: wellColor,
                    ),
                    child: Icon(goal.icon, size: 21, color: iconColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              goal.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: labelColor,
                fontWeight: started ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Goal detail sheet (tier ladder) ───────────────────────────────────────────

class _GoalDetailSheet extends StatelessWidget {
  final ReadingGoal goal;
  final ReadingStats stats;
  final Color accent;

  const _GoalDetailSheet({
    required this.goal,
    required this.stats,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final achievedIndex = goal.achievedIndex(stats);
    final current = goal.measure(stats);
    final highest = goal.highestTier(stats);
    final next = goal.nextTier(stats);
    final remaining = goal.remainingToNext(stats);
    final complete = goal.isComplete(stats);
    final headColor =
        highest != null ? badgeTierColor(highest.tier) : theme.colorScheme.onSurfaceVariant;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: highest != null
                      ? headColor.withAlpha(36)
                      : theme.colorScheme.surfaceContainerHighest,
                  border: Border.all(
                    color: highest != null ? headColor : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Icon(goal.icon, size: 38, color: headColor),
              ),
              const SizedBox(height: 14),
              Text(
                goal.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Current rank chip.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: highest != null
                      ? headColor.withAlpha(30)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: highest != null
                        ? headColor.withAlpha(110)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      highest != null
                          ? Icons.workspace_premium_rounded
                          : Icons.lock_open_rounded,
                      size: 14,
                      color: headColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      highest != null
                          ? '${badgeTierLabel(highest.tier)} · ${highest.title}'
                          : 'Unranked',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: headColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Forward path — one line: how far, and the reward it unlocks.
              if (!complete && next != null) ...[
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${goal.formatValue(remaining ?? 0)} ',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: accent,
                        ),
                      ),
                      TextSpan(
                        text: 'until ',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextSpan(
                        text: next.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: goal.progress(stats),
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      goal.formatShortValue(current),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      goal.formatShortValue(next.threshold),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ] else if (complete) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_rounded, size: 18, color: headColor),
                    const SizedBox(width: 6),
                    Text(
                      'Maxed out — ${goal.formatValue(current)} total',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: headColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              Divider(color: theme.dividerColor.withAlpha(80)),
              const SizedBox(height: 4),
              // Tier ladder — the next tier is highlighted so the goal still
              // points forward even while showing what's already earned.
              ...List.generate(goal.tiers.length, (i) {
                final t = goal.tiers[i];
                final earned = i <= achievedIndex;
                final isNext = i == achievedIndex + 1;
                final color = badgeTierColor(t.tier);
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isNext ? accent.withAlpha(22) : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        earned
                            ? Icons.check_circle
                            : (isNext
                                ? Icons.radio_button_unchecked
                                : Icons.lock_outline),
                        size: 20,
                        color: earned
                            ? color
                            : (isNext
                                ? accent
                                : theme.colorScheme.onSurfaceVariant
                                    .withAlpha(120)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: (earned || isNext)
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: (earned || isNext)
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        goal.formatShortValue(t.threshold),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isNext
                              ? accent
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight:
                              isNext ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
