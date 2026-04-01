import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../data/services/import_export_service.dart';
import '../../../viewmodels/SettingsViewModel.dart';

enum _ImportState { idle, loading, success, error }

class OnboardingPage extends StatefulWidget {
  final VoidCallback onDone;
  final ImportExportService importExportService;
  final bool hasBooks;

  const OnboardingPage({
    super.key,
    required this.onDone,
    required this.importExportService,
    required this.hasBooks,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _currentPage = 0;
  bool _hasImported = false;

  static const _infoPages = [
    _OnboardingData(
      imagePath: 'assets/icon/readstats.png',
      title: 'Welcome to ReadStats',
      body: 'Track your books, understand your habits, and turn reading into something you can actually measure.',
    ),
    _OnboardingData(
      icon: FluentIcons.library_24_filled,
      title: 'Build Your Library',
      body: 'Add books with covers, ratings, and reviews. Keep everything organized with shelves, tags, and favorites.',
    ),
    _OnboardingData(
      icon: FluentIcons.calendar_24_filled,
      title: 'Log Reading Sessions',
      body: 'Log your reading sessions and watch your progress grow over time. Visualize your habits with a simple calendar view.',
    ),
    _OnboardingData(
      icon: FluentIcons.data_pie_24_filled,
      title: 'Track Your Progress',
      body: 'Compare months, uncover trends, and see exactly how your reading has evolved over time.',
    ),
  ];

  int get _totalPages => _infoPages.length + (widget.hasBooks ? 0 : 1);

  bool get _isLastPage => _currentPage == _totalPages - 1;

  Future<void> _finish() async {
    await SettingsViewModel.setHasSeenOnboarding();
    widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _totalPages,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, i) {
                  if (i < _infoPages.length) {
                    return _PageContent(data: _infoPages[i]);
                  }
                  return _ImportContent(
                    importExportService: widget.importExportService,
                    onImportSuccess: () => setState(() => _hasImported = true),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SmoothPageIndicator(
                controller: _controller,
                count: _totalPages,
                effect: ExpandingDotsEffect(
                  dotHeight: 12,
                  dotWidth: 12,
                  expansionFactor: 3,
                  spacing: 6,
                  dotColor: colorScheme.outlineVariant,
                  activeDotColor: colorScheme.primary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: FilledButton(
                onPressed: _isLastPage
                    ? _finish
                    : () => _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: Text(
                  _isLastPage
                      ? (_hasImported ? 'Go to My Library' : 'Get Started')
                      : 'Continue',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Info page ────────────────────────────────────────────────────────────────

class _PageContent extends StatelessWidget {
  final _OnboardingData data;

  const _PageContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(32),
            ),
            child: data.imagePath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Image.asset(
                      data.imagePath!,
                      width: 180,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  )
                : Icon(data.icon, size: 80, color: colorScheme.primary),
          ),
          const SizedBox(height: 40),
          Text(
            data.title,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            data.body,
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Import page ──────────────────────────────────────────────────────────────

class _ImportContent extends StatefulWidget {
  final ImportExportService importExportService;
  final VoidCallback onImportSuccess;

  const _ImportContent({
    required this.importExportService,
    required this.onImportSuccess,
  });

  @override
  State<_ImportContent> createState() => _ImportContentState();
}

class _ImportContentState extends State<_ImportContent> {
  final Map<String, _ImportState> _states = {
    'goodreads': _ImportState.idle,
    'books': _ImportState.idle,
  };
  final Map<String, String> _messages = {};

  Future<void> _runImport(
    String key,
    Future<ImportExportResult> Function() fn,
  ) async {
    setState(() => _states[key] = _ImportState.loading);
    final result = await fn();
    final importedZero = result.success && result.message.startsWith('Imported 0');
    setState(() {
      _states[key] = importedZero
          ? _ImportState.error
          : result.success
              ? _ImportState.success
              : _ImportState.error;
      _messages[key] = importedZero ? 'No books found. Try a different file.' : result.message;
    });
    if (result.success && !importedZero) widget.onImportSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
          Text(
            'Import Your Books',
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'To help you get started, you can import your existing books now or any time later in Settings.',
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          _ImportTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icon/goodreads.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
            title: 'Import from Goodreads',
            subtitle: null,
            state: _states['goodreads']!,
            message: _messages['goodreads'],
            onTap: () => _runImport(
              'goodreads',
              widget.importExportService.importGoodreadsCSV,
            ),
          ),
          const SizedBox(height: 16),
          _ImportTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icon/readstats.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
            title: 'Import from ReadStats',
            subtitle: null,
            state: _states['books']!,
            message: _messages['books'],
            onTap: () => _runImport(
              'books',
              widget.importExportService.importBooksFromCSV,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FluentIcons.info_16_regular,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'You can import sessions and more in Settings',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
          ),
        ),
      ),
    );
  }

}

class _ImportTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final _ImportState state;
  final String? message;
  final VoidCallback onTap;

  const _ImportTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.state,
    required this.message,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoading = state == _ImportState.loading;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: leading,
        title: Text(title),
        subtitle: (state == _ImportState.success || state == _ImportState.error) && message != null
            ? Text(
                message!,
                style: TextStyle(
                  color: state == _ImportState.success ? Colors.green : colorScheme.error,
                ),
              )
            : subtitle != null
                ? Text(subtitle!)
                : null,
        trailing: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              )
            : state == _ImportState.success
                ? const Icon(Icons.check_circle, color: Colors.green)
                : state == _ImportState.error
                    ? Icon(Icons.error, color: colorScheme.error)
                    : Icon(
                        FluentIcons.chevron_right_24_filled,
                        color: colorScheme.onSurfaceVariant,
                      ),
        onTap: isLoading || state == _ImportState.success ? null : onTap,
      ),
    );
  }
}

// ─── Data class ───────────────────────────────────────────────────────────────

class _OnboardingData {
  final IconData? icon;
  final String? imagePath;
  final String title;
  final String body;

  const _OnboardingData({
    this.icon,
    this.imagePath,
    required this.title,
    required this.body,
  });
}
