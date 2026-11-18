import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '/ui/widgets/field_decoration.dart';
import '../../widgets/app_snackbar.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:read_stats/ui/pages/library/widgets/book_tag_editor_page.dart';
import 'package:read_stats/ui/pages/library/widgets/barcode_scanner_page.dart';
import 'package:read_stats/data/services/book_search_service.dart';
import '../../../data/database/database_helper.dart';
import '../../../data/models/book.dart';
import '../../../data/models/tag.dart';
import '../../../data/repositories/book_repository.dart';
import '../../../data/repositories/series_repository.dart';
import '../../../data/repositories/tag_repository.dart';
import '../../../data/utils/series_title.dart';
import '../../../data/utils/money.dart';
import '../../../data/services/cover_service.dart';
import 'widgets/cover_search_sheet.dart';
import 'widgets/edition_picker_page.dart';
import 'widgets/cover_camera_page.dart';
import '/ui/widgets/image_editor_page.dart';
import '/viewmodels/settings_view_model.dart';

class BookFormPage extends StatefulWidget {
  final Map<String, dynamic>? book;
  final BookSearchResult? searchResult;
  final Function(Map<String, dynamic>) onSave;
  final SettingsViewModel settingsViewModel;
  final bool isEditing;

  // ── Return-only mode (used by batch scan) ──────────────────────────────────
  // When [onSubmitData] is set, the form persists nothing: Save assembles the
  // book data and hands it back (with any chosen cover file and tag ids) so the
  // caller can save it later. [initialData]/[initialTagIds] prefill the fields.
  final Map<String, dynamic>? initialData;
  final Set<int>? initialTagIds;
  final void Function(
    Map<String, dynamic> data,
    File? coverFile,
    List<int> tagIds,
  )?
  onSubmitData;

  /// With [coverSettled], the cover the form opens with: the caller already
  /// holds the book's cover (or knows it has none), so [searchResult]'s is
  /// not downloaded over it. Batch scan re-opens the form for a queued book
  /// this way, so a cover chosen there survives a second visit.
  final File? initialCover;
  final bool coverSettled;

  /// Prefills the series fields of a new book — adding one for a series gap.
  final String? initialSeriesName;
  final double? initialSeriesPosition;

  const BookFormPage({
    super.key,
    this.book,
    this.searchResult,
    required this.onSave,
    required this.settingsViewModel,
    this.initialData,
    this.initialTagIds,
    this.onSubmitData,
    this.initialCover,
    this.coverSettled = false,
    this.initialSeriesName,
    this.initialSeriesPosition,
  }) : isEditing = book != null;

  bool get isReturnMode => onSubmitData != null;

  @override
  State<BookFormPage> createState() => _BookFormPageState();
}

class _BookFormPageState extends State<BookFormPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _wordCountController = TextEditingController();
  final TextEditingController _pageCountController = TextEditingController();
  final TextEditingController _ratingController = TextEditingController();
  final TextEditingController _isbnController = TextEditingController();
  final TextEditingController _userReviewController = TextEditingController();
  final TextEditingController _durationHoursController =
      TextEditingController();
  final TextEditingController _durationMinutesController =
      TextEditingController();
  final TextEditingController _narratorController = TextEditingController();
  final TextEditingController _pricePaidController = TextEditingController();
  final TextEditingController _seriesController = TextEditingController();
  final TextEditingController _seriesPositionController =
      TextEditingController();
  final FocusNode _seriesFocus = FocusNode();
  List<String> _seriesNames = const [];
  final DateTime _dateToday = DateTime.now();
  double? _rating;
  bool _isFavorite = false;
  int _shelfId = DatabaseHelper.shelfWantToRead;
  List<Map<String, dynamic>> _shelves = [];
  int _selectedBookType = 0;
  DateTime? _dateStarted;
  DateTime? _datePurchased;
  DateTime? _dateFinished;
  late bool _useStarRating;
  Set<int> _selectedTagIds = {};
  bool _titleTitleCaseEnabled = true;
  bool _authorTitleCaseEnabled = true;
  /// The cover as it will be saved, and the only one the form draws. A cover
  /// from the internet is shown once it has been downloaded, never straight
  /// from its URL: drawing the URL and saving a separate download of it let
  /// the two come apart, so the form could show a cover it didn't save.
  File? _coverFile;
  // The full, pre-crop image behind the current cover. The editor re-loads this
  // so the user can always zoom out / reposition against the whole image rather
  // than the already-cropped result. Null when the cover was never run through
  // the editor (an online/search cover is itself already the full image).
  File? _coverOriginalFile;
  /// Frames the crop editor and every place the cover is later drawn.
  int _coverShape = DatabaseHelper.coverShapePortrait;
  // Whether that shape is one the reader cropped a cover to. Until it is, a
  // new book's shape follows its format — see [_shapeFollowsFormat].
  bool _coverShapeChosen = false;
  bool _coverChanged = false;
  // True only when the user explicitly removed the cover, which is the only
  // thing that deletes one: a replacement that fails to download leaves the
  // existing cover in place.
  bool _coverRemoved = false;
  bool _isPickingCover = false;
  bool _isSaving = false;
  // A cover on its way down (search result, edition, online search or ISBN
  // lookup), completing with whether it arrived. _saveBook awaits this so
  // saving quickly can't drop the image.
  Future<bool>? _coverLoad;
  bool _coverLoading = false;
  // Counts cover changes, so a download that finishes after the reader has
  // moved on to another cover can't put the old one back.
  int _coverRequest = 0;

  /// The Open Library work this book is, which is what lists its editions.
  String? _workKey;

  /// The edition picked, or found by its ISBN, in this visit to the form.
  BookEdition? _edition;

  // What Open Library last put in the series fields, so a later lookup may
  // replace it but never what the reader typed; and a count so a slow
  // lookup can't land over a newer one.
  String? _filledSeriesName;
  String? _filledSeriesPosition;
  int _seriesRequest = 0;

  @override
  void initState() {
    super.initState();
    _useStarRating =
        widget.settingsViewModel.defaultRatingStyleNotifier.value == 0;
    _selectedBookType =
        widget.settingsViewModel.defaultBookTypeNotifier.value - 1;
    _loadShelves();
    SeriesRepository(DatabaseHelper()).names().then((names) {
      if (mounted) setState(() => _seriesNames = names);
    });

    _workKey = widget.isEditing
        ? widget.book!['open_library_key'] as String?
        : widget.searchResult?.workKey;
    if (widget.searchResult != null) {
      _prefillFromSearchResult(widget.searchResult!);
    }
    if (widget.coverSettled) _coverFile = widget.initialCover;

    if (widget.initialSeriesName != null) {
      _seriesController.text = widget.initialSeriesName!;
      _seriesPositionController.text =
          _formatSeriesPosition(widget.initialSeriesPosition);
    }

    if (widget.isReturnMode && widget.initialData != null) {
      // Override the search-result prefill with the queued item's current
      // values so edits round-trip.
      final d = widget.initialData!;
      _titleController.text = d['title'] ?? _titleController.text;
      _authorController.text = d['author'] ?? _authorController.text;
      if (d['page_count'] != null) {
        _pageCountController.text = d['page_count'].toString();
      }
      _isbnController.text = d['isbn'] ?? _isbnController.text;
      _rating = (d['rating'] as num?)?.toDouble();
      _ratingController.text = _rating?.toStringAsFixed(2) ?? '';
      _shelfId = (d['shelf_id'] as int?) ?? DatabaseHelper.shelfWantToRead;
      _isFavorite = d['is_favorite'] == 1;
      _selectedBookType = ((d['book_type_id'] as int?) ?? 1) - 1;
      _narratorController.text = d['narrator'] ?? _narratorController.text;
      _pricePaidController.text = Money.forField(d['price_paid'] as num?);
      _datePurchased =
          DateTime.tryParse(d['date_purchased']?.toString() ?? '');
      _seriesController.text = d['series_name'] ?? '';
      _seriesPositionController.text = _formatSeriesPosition(d['series_position']);
      _selectedTagIds = {...?widget.initialTagIds};
      final shape = d['cover_shape'] as int?;
      if (shape != null) {
        _coverShape = shape;
        _coverShapeChosen = true;
      }
    }

    if (widget.isEditing) {
      _titleController.text = widget.book!['title'];
      _authorController.text = widget.book!['author'];
      final editWordCount = widget.book!['word_count'] as int?;
      final editPageCount = widget.book!['page_count'] as int?;
      if (editWordCount != null && editWordCount > 0) {
        _wordCountController.text = editWordCount.toString();
      }
      if (editPageCount != null && editPageCount > 0) {
        _pageCountController.text = editPageCount.toString();
      }
      _rating = widget.book!['rating']?.toDouble();
      _ratingController.text = _rating?.toStringAsFixed(2) ?? '';
      _shelfId = (widget.book!['shelf_id'] as int?) ?? 1;
      _isFavorite = widget.book!['is_favorite'] == 1;
      _selectedBookType = widget.book!['book_type_id'] - 1;
      final editDuration = widget.book!['duration_minutes'] as int?;
      if (editDuration != null && editDuration > 0) {
        _durationHoursController.text = (editDuration ~/ 60).toString();
        _durationMinutesController.text = (editDuration % 60).toString();
      }
      _narratorController.text = widget.book!['narrator'] ?? '';
      _pricePaidController.text =
          Money.forField(widget.book!['price_paid'] as num?);
      _datePurchased = DateTime.tryParse(
          widget.book!['date_purchased']?.toString() ?? '');
      _seriesController.text = widget.book!['series_name'] ?? '';
      _seriesPositionController.text =
          _formatSeriesPosition(widget.book!['series_position']);
      _isbnController.text = widget.book!['isbn'] ?? '';
      _userReviewController.text = widget.book!['user_review'] ?? '';
      _dateStarted = widget.book!['date_started'] != null
          ? DateTime.parse(widget.book!['date_started'])
          : null;
      _dateFinished = widget.book!['date_finished'] != null
          ? DateTime.parse(widget.book!['date_finished'])
          : null;
      _loadExistingTags();
      if (widget.book!['cover_path'] != null) {
        _coverFile = File(widget.book!['cover_path'] as String);
      }
      _coverShape = (widget.book!['cover_shape'] as int?) ??
          DatabaseHelper.coverShapePortrait;
    }
    _shapeFollowsFormat();
  }

  /// Gives a new book the cover shape its format usually has — square for an
  /// audiobook — whenever the format is set or changes. Stops once the
  /// reader has cropped a cover to a shape, and never touches a book already
  /// in the library, whose cover was framed for the shape it has.
  void _shapeFollowsFormat() {
    if (widget.isEditing || _coverShapeChosen) return;
    _coverShape = DatabaseHelper.defaultCoverShape(_selectedBookType + 1);
  }

  Future<void> _loadShelves() async {
    final shelves = await BookRepository(DatabaseHelper()).getShelves();
    if (mounted) {
      setState(() {
        _shelves = shelves;
        // Guard: if current shelfId isn't in the loaded list, fall back to first
        if (_shelves.isNotEmpty && !_shelves.any((s) => s['id'] == _shelfId)) {
          _shelfId = DatabaseHelper.shelfWantToRead;
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _wordCountController.dispose();
    _pageCountController.dispose();
    _ratingController.dispose();
    _isbnController.dispose();
    _userReviewController.dispose();
    _durationHoursController.dispose();
    _durationMinutesController.dispose();
    _narratorController.dispose();
    _pricePaidController.dispose();
    _seriesController.dispose();
    _seriesPositionController.dispose();
    _seriesFocus.dispose();
    super.dispose();
  }

  static String _formatSeriesPosition(dynamic value) {
    final position = (value as num?)?.toDouble();
    return position == null ? '' : SeriesTitle.formatPosition(position);
  }

  void _saveBook() async {
    // Saving awaits cover downloads/file writes, so a quick second tap would
    // run a second save and pop the route twice — leaving a black screen.
    if (_isSaving) return;
    _isSaving = true;

    String title = _titleController.text.trim();
    String author = _authorController.text.trim();
    final bool savingAsAudiobook = _selectedBookType == 3;
    final int? wordCount = savingAsAudiobook
        ? null
        : int.tryParse(_wordCountController.text);
    final int? pageCount = savingAsAudiobook
        ? null
        : int.tryParse(_pageCountController.text);

    if (title.isEmpty || author.isEmpty) {
      _isSaving = false;
      return;
    }

    final bookRepository = BookRepository(DatabaseHelper());
    // Return mode never touches the DB, so skip the duplicate lookup/dialog —
    // the batch review list handles duplicate flagging itself.
    final bookExists = widget.isReturnMode
        ? false
        : await bookRepository.doesBookExist(
            title,
            author,
            excludeId: widget.isEditing ? widget.book!['id'] : null,
          );

    if (!mounted) return;
    if (bookExists && !widget.isEditing) {
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Duplicate Book'),
          content: const Text(
            'A book with this title and author already exists. '
            'Are you sure you want to add it anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add Anyway'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) {
        _isSaving = false;
        return;
      }
    }

    // A number without a series means nothing, so it goes with the name.
    final seriesName = _seriesController.text.trim();
    final int? seriesId = seriesName.isEmpty
        ? null
        : await SeriesRepository(DatabaseHelper()).idFor(seriesName);
    final double? seriesPosition = seriesName.isEmpty
        ? null
        : double.tryParse(_seriesPositionController.text.trim());

    final bookData = {
      if (widget.isEditing && widget.book!['id'] != null)
        "id": widget.book!['id'],
      "series_id": seriesId,
      "series_position": seriesPosition,
      // Carried for return mode (batch scan), which re-opens the form from
      // this map; the database ignores it.
      if (widget.isReturnMode && seriesName.isNotEmpty)
        "series_name": seriesName,
      "title": title,
      "author": author,
      "word_count": wordCount,
      "page_count": pageCount,
      "rating": _rating?.toDouble(),
      "is_favorite": _isFavorite ? 1 : 0,
      "shelf_id": _shelfId,
      "book_type_id": _selectedBookType + 1,
      "date_started": _dateStarted?.toIso8601String(),
      // Only ever what the reader entered. Shelving a book as Finished used to
      // stamp today's date when the field was empty, which guessed at a date
      // the reader may not know and made clearing the field impossible — it
      // came back as today on the next save.
      "date_finished": _dateFinished?.toIso8601String(),
      "date_added": widget.isEditing
          ? widget.book!['date_added']
          : DateTime.now().toIso8601String(),
      "isbn": _isbnController.text.trim().isEmpty
          ? null
          : _isbnController.text.replaceAll(RegExp(r'[\s-]'), ''),
      "duration_minutes": () {
        if (!savingAsAudiobook) return null;
        final h = int.tryParse(_durationHoursController.text) ?? 0;
        final m = int.tryParse(_durationMinutesController.text) ?? 0;
        final total = h * 60 + m;
        return total > 0 ? total : null;
      }(),
      // Written whatever the format. The field is only shown for audiobooks,
      // but a narrator already entered survives a switch to another format —
      // switching back shouldn't mean typing the name again.
      "narrator": _narratorController.text.trim().isEmpty
          ? null
          : _narratorController.text.trim(),
      // Written whether or not the field is showing, like the narrator:
      // turning spending off hides it, and a save made meanwhile must not
      // wipe what was entered.
      "price_paid": Money.parse(_pricePaidController.text),
      "date_purchased": _datePurchased?.toIso8601String(),
      "user_review": _userReviewController.text.trim().isEmpty
          ? null
          : _userReviewController.text.trim(),
      // Filename only. The form receives a resolved absolute path for display;
      // writing that back would break after an iOS app update changes the
      // sandbox UUID.
      "cover_path": widget.isEditing && widget.book!['cover_path'] != null
          ? p.basename(widget.book!['cover_path'] as String)
          : null,
      "cover_shape": _coverShape,
      "open_library_key": _workKey,
    };

    // A cover picked from search or a URL may still be downloading — wait for
    // it here rather than silently saving the book without its image. If it
    // never arrives the book keeps the cover on screen, and the reader is
    // told the new one was lost.
    final coverLoad = _coverLoad;
    final lostCover = coverLoad != null && !await coverLoad;
    final File? coverFile = _coverFile;

    // Return mode: hand the assembled data back and let the caller persist.
    if (widget.isReturnMode) {
      widget.onSubmitData!(bookData, coverFile, _selectedTagIds.toList());
      if (lostCover) {
        AppSnackbar.show("The cover couldn't be downloaded", isError: true);
      }
      if (mounted) Navigator.pop(context);
      return;
    }

    try {
      if (widget.isEditing && widget.book!['id'] != null) {
        final bookId = widget.book!['id'] as int;
        await bookRepository.updateBook(Book.fromMap(bookData));

        final tagRepo = TagRepository(DatabaseHelper());
        final currentTags = await tagRepo.getTagsForBook(bookId);
        final currentTagIds = currentTags.map((t) => t.id!).toSet();

        for (final tagId in _selectedTagIds) {
          if (!currentTagIds.contains(tagId)) {
            await tagRepo.addTagToBook(bookId, tagId);
          }
        }

        for (final tagId in currentTagIds) {
          if (!_selectedTagIds.contains(tagId)) {
            await tagRepo.removeTagFromBook(bookId, tagId);
          }
        }

        if (_coverChanged) {
          if (coverFile != null) {
            final newPath = await CoverService.saveFromPath(
              bookId,
              coverFile.path,
            );
            await bookRepository.updateCoverPath(bookId, newPath);
            await _persistCoverOriginal(bookId);
          } else if (_coverRemoved) {
            await CoverService.deleteByPath(
              widget.book!['cover_path'] as String?,
            );
            await CoverService.delete(bookId);
            await bookRepository.updateCoverPath(bookId, null);
          }
          // Otherwise a replacement failed to download — keep the old cover.
        }
      } else {
        final newBookId = await bookRepository.addBook(Book.fromMap(bookData));

        if (_selectedTagIds.isNotEmpty) {
          final tagRepo = TagRepository(DatabaseHelper());
          for (final tagId in _selectedTagIds) {
            await tagRepo.addTagToBook(newBookId, tagId);
          }
        }

        if (coverFile != null) {
          final newPath = await CoverService.saveFromPath(
            newBookId,
            coverFile.path,
          );
          await bookRepository.updateCoverPath(newBookId, newPath);
          await _persistCoverOriginal(newBookId);
        }
      }

      widget.onSave(bookData);
      _handleSaveSuccess(lostCover: lostCover);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving book: $e');
      _isSaving = false;
    }
  }

  Future<void> _loadExistingTags() async {
    try {
      if (widget.book!['id'] != null) {
        final tags = await TagRepository(
          DatabaseHelper(),
        ).getTagsForBook(widget.book!['id']);
        setState(() {
          _selectedTagIds = tags.map((tag) => tag.id!).toSet();
        });
      }
    } catch (e) {
      debugPrint('Error loading tags: $e');
    }
  }

  void _handleSaveSuccess({bool lostCover = false}) {
    if (lostCover) {
      AppSnackbar.show(
        widget.isEditing
            ? "Book updated, but the new cover couldn't be downloaded"
            : "Book added, but its cover couldn't be downloaded",
        isError: true,
      );
    } else {
      AppSnackbar.show(
        widget.isEditing
            ? 'Book updated successfully!'
            : 'Book added successfully!',
      );
    }
    if (!widget.isEditing) {
      _clearFormInputs();
    }
  }

  void _clearFormInputs() {
    _titleController.clear();
    _authorController.clear();
    _wordCountController.clear();
    _pageCountController.clear();
    _isbnController.clear();
    _userReviewController.clear();
    _narratorController.clear();
    _pricePaidController.clear();
    _seriesController.clear();
    _seriesPositionController.clear();
    _seriesRequest++;
    _filledSeriesName = null;
    _filledSeriesPosition = null;
    setState(() {
      _datePurchased = null;
      _rating = 0;
      _isFavorite = false;
      _shelfId = DatabaseHelper.shelfWantToRead;
      _durationHoursController.clear();
      _durationMinutesController.clear();
      _selectedBookType =
          widget.settingsViewModel.defaultBookTypeNotifier.value - 1;
      _dateStarted = null;
      _dateFinished = null;
    });
  }

  void _prefillFromSearchResult(BookSearchResult result) {
    _titleController.text = result.title;
    _authorController.text = result.author;
    if (result.pageCount != null) {
      _pageCountController.text = result.pageCount.toString();
    }
    if (result.isbn != null) _isbnController.text = result.isbn!;
    _edition = result.edition;
    final type = result.edition?.bookTypeId;
    if (type != null) _selectedBookType = type - 1;
    _fillAudio(result.edition);
    _fillSeries(result.edition, result.workKey);
    final cover = result.coverUrl ?? result.thumbnailUrl;
    if (cover != null && !widget.coverSettled) _loadCoverFromUrl(cover);
  }

  /// Fills in the series and number where Open Library knows them, spelled
  /// the way the reader already has that series so it joins theirs rather
  /// than starting a second one. Never replaces what the reader typed — only
  /// what an earlier lookup filled in, as when another edition is picked.
  Future<void> _fillSeries(BookEdition? edition, String? workKey) async {
    final request = ++_seriesRequest;
    final found =
        await BookSearchService.seriesFor(edition: edition, workKey: workKey);
    if (found == null || !mounted || request != _seriesRequest) return;
    final name =
        await SeriesRepository(DatabaseHelper()).existingName(found.name) ??
            found.name;
    if (!mounted || request != _seriesRequest) return;

    final typedName = _seriesController.text.trim();
    final ownName = typedName.isNotEmpty && typedName != _filledSeriesName;
    // The reader named a different series: theirs stands, number and all.
    if (ownName &&
        SeriesTitle.matchKey(typedName) != SeriesTitle.matchKey(name)) {
      return;
    }
    final typedPosition = _seriesPositionController.text.trim();
    final ownPosition =
        typedPosition.isNotEmpty && typedPosition != _filledSeriesPosition;
    final position = found.position == null
        ? ''
        : SeriesTitle.formatPosition(found.position!);

    setState(() {
      if (!ownName) {
        _seriesController.text = name;
        _filledSeriesName = name;
      }
      if (!ownPosition) {
        _seriesPositionController.text = position;
        _filledSeriesPosition = position;
      }
    });
  }

  /// Fills in an audiobook's length and narrator from its edition, where
  /// Open Library has them. The fields only show for an audiobook.
  void _fillAudio(BookEdition? edition) {
    final minutes = edition?.durationMinutes;
    if (minutes != null) {
      _durationHoursController.text = (minutes ~/ 60).toString();
      _durationMinutesController.text = (minutes % 60).toString();
    }
    final narrator = edition?.narrator;
    if (narrator != null) _narratorController.text = narrator;
  }

  /// Downloads the cover at [url] and makes it the book's, completing with
  /// whether it arrived. Until then the form keeps showing the cover it had,
  /// under a spinner; if the download fails that cover stays, and the reader
  /// is told. So the cover on screen is always the one a save would store.
  Future<bool> _loadCoverFromUrl(String url) {
    final request = ++_coverRequest;
    final load = () async {
      final file = await CoverService.downloadFromUrl(url);
      // The reader chose another cover, or removed it, in the meantime.
      if (!mounted || request != _coverRequest) return false;
      setState(() {
        _coverLoading = false;
        _coverLoad = null;
        if (file != null) {
          _coverFile = file;
          _coverOriginalFile = null;
          _coverChanged = true;
          _coverRemoved = false;
        }
      });
      // A save that is waiting on this reports the loss itself.
      if (file == null && !_isSaving) {
        AppSnackbar.show("Couldn't download that cover", isError: true);
      }
      return file != null;
    }();
    setState(() {
      _coverLoad = load;
      _coverLoading = true;
    });
    return load;
  }

  /// Stops a cover that is downloading from landing: the reader has chosen
  /// something else. Call inside setState.
  void _cancelCoverLoad() {
    _coverRequest++;
    _coverLoading = false;
    _coverLoad = null;
  }

  Future<void> _chooseEdition() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final choice = await Navigator.of(context).push<EditionChoice>(
      MaterialPageRoute(
        builder: (_) => EditionPickerPage(
          workKey: _workKey,
          isbn: _isbnController.text,
        ),
      ),
    );
    final edition = choice?.edition;
    if (edition == null || !mounted) return;
    _applyEdition(edition, choice!.workKey);
  }

  /// Makes the book the edition the reader picked: its cover, ISBN and page
  /// count, which then all describe the same copy. What the edition doesn't
  /// record is left as it is. A new book also takes the edition's title and
  /// format; one already in the library keeps its own, which the reader may
  /// have set and which sessions were logged against.
  void _applyEdition(BookEdition edition, String? workKey) {
    setState(() {
      _edition = edition;
      _workKey = workKey ?? _workKey;
      if (edition.isbn != null) _isbnController.text = edition.isbn!;
      if (edition.pageCount != null) {
        _pageCountController.text = edition.pageCount.toString();
      }
      _fillAudio(edition);
      _fillSeries(edition, _workKey);
      if (!widget.isEditing) {
        if (edition.title.isNotEmpty) _titleController.text = edition.title;
        final type = edition.bookTypeId;
        if (type != null) _selectedBookType = type - 1;
        _shapeFollowsFormat();
      }
    });
    final cover = edition.coverUrl;
    if (cover != null) {
      _loadCoverFromUrl(cover);
    } else if (_coverFile != null || _coverLoading) {
      AppSnackbar.show(
        'That edition has no cover on Open Library, so the cover is unchanged',
      );
    }
  }

  Future<void> _lookupByIsbn(String isbn) async {
    final result = await BookSearchService.lookupByIsbn(isbn);
    if (result == null || !mounted) return;
    if (_titleController.text.isEmpty) {
      _titleController.text = result.title;
    }
    if (_authorController.text.isEmpty) {
      _authorController.text = result.author;
    }
    if (_pageCountController.text.isEmpty && result.pageCount != null) {
      _pageCountController.text = result.pageCount.toString();
    }
    _fillSeries(result.edition, result.workKey);
    setState(() {});
    final cover = result.coverUrl ?? result.thumbnailUrl;
    if (_coverFile == null && !_coverLoading && cover != null) {
      await _loadCoverFromUrl(cover);
    }
  }

  void _clearStartDate() {
    setState(() {
      _dateStarted = null;
    });
  }

  void _clearFinishDate() {
    setState(() {
      _dateFinished = null;
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? _dateStarted ?? _dateToday
          : _dateFinished ?? _dateStarted ?? _dateToday,
      firstDate: isStartDate ? DateTime(1900) : _dateStarted ?? DateTime(1900),
      lastDate: _dateToday,
      builder: (BuildContext context, Widget? child) {
        return Theme(data: Theme.of(context), child: child!);
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _dateStarted = picked;
          if (_dateFinished != null && _dateFinished!.isBefore(picked)) {
            _dateFinished = null;
          }
          // Auto-advance to Currently Reading only if currently on Want to Read
          if (_shelfId == DatabaseHelper.shelfWantToRead) {
            _shelfId = DatabaseHelper.shelfCurrentlyReading;
          }
        } else {
          _dateFinished = picked;
          _shelfId = DatabaseHelper.shelfFinished;
        }
      });
    }
  }

  Future<List<Tag>> _getTagsByIds(List<int> tagIds) async {
    if (tagIds.isEmpty) return [];
    final allTags = await TagRepository(DatabaseHelper()).getAllTags();
    return allTags.where((tag) => tagIds.contains(tag.id)).toList();
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;

    final wordsToLowercase = {
      'a',
      'an',
      'the',
      'and',
      'but',
      'or',
      'nor',
      'as',
      'at',
      'by',
      'for',
      'from',
      'in',
      'into',
      'near',
      'of',
      'on',
      'onto',
      'to',
      'with',
    };

    final words = text.split(' ');
    final result = StringBuffer();

    for (int i = 0; i < words.length; i++) {
      if (words[i].isNotEmpty) {
        final currentWord = words[i].toLowerCase();

        if (i == 0 || !wordsToLowercase.contains(currentWord)) {
          result.write(words[i][0].toUpperCase());
          if (words[i].length > 1) {
            result.write(words[i].substring(1).toLowerCase());
          }
        } else {
          result.write(currentWord);
        }

        if (i < words.length - 1) {
          result.write(' ');
        }
      }
    }

    return result.toString();
  }

  /// Bottom-sheet chooser for where the cover comes from. Currently online
  /// (Open Library) search and the device photo library; leaves room for a
  /// general internet image search later.
  Future<void> _showCoverSourceSheet() async {
    final theme = Theme.of(context);
    final source = await showModalBottomSheet<_CoverSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('Search online'),
              subtitle: const Text('Find a cover from Open Library'),
              onTap: () => Navigator.pop(ctx, _CoverSource.online),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo library'),
              subtitle: const Text('Choose an image from your device'),
              onTap: () => Navigator.pop(ctx, _CoverSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              subtitle: const Text('Capture a cover with your camera'),
              onTap: () => Navigator.pop(ctx, _CoverSource.camera),
            ),
          ],
        ),
      ),
      backgroundColor: theme.colorScheme.surfaceContainer,
    );

    if (source == null || !mounted) return;
    switch (source) {
      case _CoverSource.online:
        await _searchCoverOnline();
      case _CoverSource.gallery:
        await _pickCoverFromGallery();
      case _CoverSource.camera:
        await _pickCoverFromCamera();
    }
  }

  Future<void> _pickCoverFromGallery() async {
    if (_isPickingCover) return;
    setState(() => _isPickingCover = true);
    try {
      final file = await CoverService.pickImage();
      await _applyPickedCover(file);
    } finally {
      if (mounted) setState(() => _isPickingCover = false);
    }
  }

  /// Capture a cover via the in-app camera (back camera by default, with
  /// swap/flash controls), then run it through the crop editor.
  Future<void> _pickCoverFromCamera() async {
    if (_isPickingCover) return;
    setState(() => _isPickingCover = true);
    try {
      final file = await Navigator.of(context).push<File>(
        MaterialPageRoute(builder: (_) => const CoverCameraPage()),
      );
      if (!mounted) return;
      await _applyPickedCover(file);
    } finally {
      if (mounted) setState(() => _isPickingCover = false);
    }
  }

  /// Shared handling for a freshly picked/captured cover [file]: run the crop
  /// editor and, if the user keeps the result, store it as the new cover.
  Future<void> _applyPickedCover(File? file) async {
    if (file == null || !mounted) return;
    final shapeBefore = _coverShape;
    final edited = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => ImageEditorPage(
          imageFile: file,
          aspectRatio: DatabaseHelper.coverAspectRatio(_coverShape),
          coverShape: _coverShape,
          // The editor owns the shape choice — it can show the frame change.
          onCoverShapeChanged: (shape) => setState(() => _coverShape = shape),
        ),
      ),
    );
    if (!mounted) return;
    if (edited == null) {
      // Cancelled — the shape the editor reported never became a crop.
      setState(() => _coverShape = shapeBefore);
      return;
    }
    setState(() {
      _coverFile = edited;
      _coverOriginalFile = file;
      _coverShapeChosen = true;
      _coverChanged = true;
      _coverRemoved = false;
      _cancelCoverLoad();
    });
  }

  /// Persist (or clear) the pre-crop original that backs a saved cover.
  Future<void> _persistCoverOriginal(int bookId) async {
    if (_coverOriginalFile != null) {
      await CoverService.saveOriginalFromPath(bookId, _coverOriginalFile!.path);
    } else {
      // The cover is itself a full image (online/unedited); drop any stale
      // original from a previous edit so re-editing uses the current cover.
      await CoverService.deleteOriginal(bookId);
    }
  }

  /// Re-open the editor for the current cover so it can be re-cropped/adjusted.
  /// Edits from the full, pre-crop original when one exists — in-session, then a
  /// previously-saved original on disk — so the user can zoom back out instead
  /// of being stuck with the already-cropped image. Falls back to the current
  /// cover for online covers (already full images) and legacy pre-original data.
  Future<void> _editCurrentCover() async {
    File? source = _coverOriginalFile;
    if (source == null && widget.isEditing && widget.book!['id'] != null) {
      source = await CoverService.originalFile(widget.book!['id'] as int);
    }
    source ??= _coverFile;
    if (source == null || !mounted) return;
    final shapeBefore = _coverShape;
    final edited = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => ImageEditorPage(
          imageFile: source!,
          aspectRatio: DatabaseHelper.coverAspectRatio(_coverShape),
          coverShape: _coverShape,
          // The editor owns the shape choice — it can show the frame change.
          onCoverShapeChanged: (shape) => setState(() => _coverShape = shape),
        ),
      ),
    );
    if (!mounted) return;
    if (edited == null) {
      // Cancelled — keep the shape matching the crop that's actually stored.
      setState(() => _coverShape = shapeBefore);
      return;
    }
    setState(() {
      _coverFile = edited;
      _coverOriginalFile = source;
      _coverShapeChosen = true;
      _coverChanged = true;
      _coverRemoved = false;
      _cancelCoverLoad();
    });
  }

  Future<void> _searchCoverOnline() async {
    final query = [_titleController.text.trim(), _authorController.text.trim()]
        .where((s) => s.isNotEmpty)
        .join(' ');
    final url = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CoverSearchSheet(initialQuery: query),
      ),
    );
    if (url == null || !mounted) return;
    await _loadCoverFromUrl(url);
  }

  /// Which edition of the book this is, and the way to pick another: a
  /// search finds the book, not the reader's copy of it.
  Widget _buildEditionRow(ThemeData theme) {
    final edition = _edition;
    final muted = theme.colorScheme.onSurfaceVariant;
    final String label;
    if (edition == null) {
      label = 'Choose the one you own';
    } else if (edition.summary.isNotEmpty) {
      label = edition.summary;
    } else if (edition.isbn != null) {
      label = 'ISBN ${edition.isbn}';
    } else {
      label = edition.title.isEmpty ? 'Chosen' : edition.title;
    }
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _chooseEdition,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Icon(Icons.auto_stories, size: 20, color: muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edition',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: edition == null ? muted : null,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPicker() {
    final theme = Theme.of(context);
    const double coverW = 150;
    final double coverH =
        coverW / DatabaseHelper.coverAspectRatio(_coverShape);
    final bool hasCover = _coverFile != null;
    // Enough room for the cover plus the surrounding blurred margin. Follows
    // the cover's height so a square one doesn't sit in a portrait-sized well.
    final double areaH = hasCover || _coverLoading ? coverH + 70 : 90.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: areaH,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background — blurred cover or plain surface
            if (_coverFile != null)
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                  child: Image.file(_coverFile!, fit: BoxFit.cover),
                ),
              )
            else
              Positioned.fill(
                child: Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
              ),

            // Dim overlay so cover pops
            if (hasCover)
              Positioned.fill(
                child: Container(color: Colors.black.withValues(alpha: 0.35)),
              ),

            // Ripple layer — above backgrounds so the ink is visible
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: _isPickingCover ? null : _showCoverSourceSheet,
                ),
              ),
            ),

            // Cover image
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _coverFile != null
                      ? Image.file(
                          _coverFile!,
                          width: coverW,
                          height: coverH,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _coverPlaceholder(theme, coverW, coverH),
                        )
                      : _coverLoading
                      ? _CoverLoadingPlaceholder(
                          width: coverW,
                          height: coverH,
                          theme: theme,
                        )
                      : _emptyPlaceholder(theme),
                ),
              ],
            ),

            // A replacement on its way down. The cover underneath is still
            // the book's, and stays so if the new one never arrives.
            if (_coverLoading && hasCover)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.35),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),

            // Edit button — top-left corner.
            if (hasCover)
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  onPressed: _editCurrentCover,
                  icon: const Icon(Icons.crop, size: 22),
                  color: Colors.white,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.45),
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),

            // Remove button — top-right corner
            if (hasCover || _coverLoading)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _coverFile = null;
                      _coverOriginalFile = null;
                      _coverChanged = true;
                      _coverRemoved = true;
                      _cancelCoverLoad();
                    });
                  },
                  icon: const Icon(Icons.delete, size: 22),
                  color: Colors.white,
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.error.withValues(
                      alpha: 0.85,
                    ),
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyPlaceholder(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          'Add cover image',
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _coverPlaceholder(ThemeData theme, double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 32,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 6),
          Text(
            'Add cover',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _titleController,
            decoration: filledFieldDecoration(theme).copyWith(
              labelText: 'Title',
              hintText: 'Enter book title',
              floatingLabelBehavior: FloatingLabelBehavior.auto,
            ),
            onChanged: (value) {
              if (_titleTitleCaseEnabled && value.isNotEmpty) {
                final formattedValue = _toTitleCase(value);
                if (value != formattedValue) {
                  final cursorPos = _titleController.selection.baseOffset;
                  _titleController.value = _titleController.value.copyWith(
                    text: formattedValue,
                    selection: TextSelection.collapsed(offset: cursorPos),
                  );
                }
              }
              setState(() {});
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          height: 56,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _titleTitleCaseEnabled = !_titleTitleCaseEnabled;
                if (_titleController.text.isNotEmpty) {
                  _titleController.text = _titleTitleCaseEnabled
                      ? _toTitleCase(_titleController.text)
                      : _titleController.text.toLowerCase();
                }
              });
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _titleTitleCaseEnabled
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.text_fields,
                color: _titleTitleCaseEnabled
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthorField() {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Autocomplete<String>(
            optionsBuilder: (textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<String>.empty();
              }
              return BookRepository(
                DatabaseHelper(),
              ).getAuthorSuggestions(textEditingValue.text);
            },
            fieldViewBuilder:
                (context, textEditingController, focusNode, onFieldSubmitted) {
                  textEditingController.text = _authorController.text;
                  _authorController.addListener(() {
                    if (textEditingController.text != _authorController.text) {
                      textEditingController.text = _authorController.text;
                    }
                  });

                  return TextField(
                    controller: _authorController,
                    focusNode: focusNode,
                    decoration: filledFieldDecoration(theme).copyWith(
                      labelText: 'Author',
                      hintText: 'Enter author',
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                    ),
                    onChanged: (value) {
                      if (_authorTitleCaseEnabled && value.isNotEmpty) {
                        final formattedValue = _toTitleCase(value);
                        if (value != formattedValue) {
                          final cursorPos =
                              _authorController.selection.baseOffset;
                          _authorController.value = _authorController.value
                              .copyWith(
                                text: formattedValue,
                                selection: TextSelection.collapsed(
                                  offset: cursorPos,
                                ),
                              );
                        }
                      }
                      setState(() {});
                    },
                  );
                },
            onSelected: (selection) {
              final formatted = _authorTitleCaseEnabled
                  ? _toTitleCase(selection)
                  : selection;
              _authorController.text = formatted;
              _authorController.selection = TextSelection.fromPosition(
                TextPosition(offset: formatted.length),
              );
              setState(() {});
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          height: 56,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _authorTitleCaseEnabled = !_authorTitleCaseEnabled;
                if (_authorController.text.isNotEmpty) {
                  _authorController.text = _authorTitleCaseEnabled
                      ? _toTitleCase(_authorController.text)
                      : _authorController.text.toLowerCase();
                }
              });
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _authorTitleCaseEnabled
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.text_fields,
                color: _authorTitleCaseEnabled
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Series name (suggesting the reader's existing series) and its number.
  Widget _buildSeriesField() {
    final theme = Theme.of(context);

    InputDecoration decoration(String label, String hint) => filledFieldDecoration(theme).copyWith(
          labelText: label,
          hintText: hint,
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => RawAutocomplete<String>(
              textEditingController: _seriesController,
              focusNode: _seriesFocus,
              optionsBuilder: (value) {
                final q = value.text.trim().toLowerCase();
                if (q.isEmpty) return const Iterable<String>.empty();
                return _seriesNames.where((n) =>
                    n.toLowerCase().contains(q) && n.toLowerCase() != q);
              },
              fieldViewBuilder: (context, controller, focusNode, _) =>
                  TextField(
                controller: controller,
                focusNode: focusNode,
                textCapitalization: TextCapitalization.words,
                decoration: decoration('Series', 'Part of a series?'),
                onChanged: (_) => setState(() {}),
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
              ),
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: 220,
                      maxWidth: constraints.maxWidth,
                    ),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        for (final option in options)
                          ListTile(
                            dense: true,
                            title: Text(option),
                            onTap: () => onSelected(option),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 88,
          child: TextField(
            controller: _seriesPositionController,
            enabled: _seriesController.text.trim().isNotEmpty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            // Whole numbers, or a decimal for an in-between novella (1.5).
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: decoration('#', '1'),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = widget.settingsViewModel.accentColorNotifier.value;
    final bool isAudiobook = _selectedBookType == 3;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Book' : 'Add Book'),
        backgroundColor: theme.colorScheme.surfaceContainer,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: NotificationListener<UserScrollNotification>(
              onNotification: (n) {
                if (n.direction != ScrollDirection.idle) {
                  FocusScope.of(context).unfocus();
                }
                return false;
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCoverPicker(),
                    const SizedBox(height: 8),
                    _buildEditionRow(theme),
                    const SizedBox(height: 16),
                    _buildTitleField(),
                    const SizedBox(height: 16),
                    _buildAuthorField(),
                    const SizedBox(height: 16),
                    _buildSeriesField(),

                    const Divider(height: 32),

                    // Book Type
                    DropdownButtonFormField<int>(
                      initialValue: _selectedBookType,
                      style: theme.textTheme.bodyLarge,
                      decoration: filledFieldDecoration(theme).copyWith(
                        labelText: 'Format',
                      ),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Paperback')),
                        DropdownMenuItem(value: 1, child: Text('Hardback')),
                        DropdownMenuItem(value: 2, child: Text('eBook')),
                        DropdownMenuItem(value: 3, child: Text('Audiobook')),
                      ],
                      onChanged: (int? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedBookType = newValue;
                            _shapeFollowsFormat();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Pages and Words — hidden for audiobooks
                    if (!isAudiobook) ...[
                      TextField(
                        controller: _pageCountController,
                        decoration: filledFieldDecoration(theme).copyWith(
                          labelText: 'Pages',
                          hintText: 'Enter number of pages',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) => setState(() {}),
                        onTapOutside: (event) {
                          FocusManager.instance.primaryFocus?.unfocus();
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _wordCountController,
                        decoration: filledFieldDecoration(theme).copyWith(
                          labelText: 'Words',
                          hintText: 'Enter number of words',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => setState(() {}),
                        onTapOutside: (event) {
                          FocusManager.instance.primaryFocus?.unfocus();
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Narrator and duration — shown only for audiobooks
                    if (isAudiobook) ...[
                      TextField(
                        controller: _narratorController,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => setState(() {}),
                        onTapOutside: (_) =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        decoration: filledFieldDecoration(theme).copyWith(
                          labelText: 'Narrator',
                          // Plural because full-cast recordings are common —
                          // the field takes a comma-separated list.
                          hintText: 'Enter narrator(s)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _durationHoursController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (_) => setState(() {}),
                              onTapOutside: (_) =>
                                  FocusManager.instance.primaryFocus?.unfocus(),
                              decoration: filledFieldDecoration(theme).copyWith(
                                labelText: 'Hours',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _durationMinutesController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (v) {
                                final val = int.tryParse(v);
                                if (val != null && val > 59) {
                                  _durationMinutesController.text = '59';
                                }
                                setState(() {});
                              },
                              onTapOutside: (_) =>
                                  FocusManager.instance.primaryFocus?.unfocus(),
                              decoration: filledFieldDecoration(theme).copyWith(
                                labelText: 'Minutes',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ISBN
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _isbnController,
                              decoration: filledFieldDecoration(theme).copyWith(
                                labelText: 'ISBN',
                                hintText: '978-X-XX-XXXXXX-X',
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [IsbnInputFormatter()],
                              // Another ISBN is another edition.
                              onChanged: (value) =>
                                  setState(() => _edition = null),
                              onTapOutside: (event) {
                                FocusManager.instance.primaryFocus?.unfocus();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          AspectRatio(
                            aspectRatio: 1,
                            child: Tooltip(
                              message: 'Scan barcode',
                              child: Material(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    final result = await Navigator.of(context)
                                        .push<String>(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const BarcodeScannerPage(),
                                          ),
                                        );
                                    if (result != null) {
                                      setState(() {
                                        _isbnController.text = result;
                                        _edition = null;
                                      });
                                      _lookupByIsbn(result);
                                    }
                                  },
                                  child: const Center(
                                    child: Icon(
                                      FluentIcons.barcode_scanner_24_regular,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 32),

                    // Shelf selector
                    if (_shelves.isNotEmpty) ...[
                      DropdownButtonFormField<int>(
                        initialValue: _shelfId,
                        style: theme.textTheme.bodyLarge,
                        decoration: filledFieldDecoration(theme).copyWith(
                          labelText: 'Shelf',
                        ),
                        items: _shelves.map((shelf) {
                          return DropdownMenuItem<int>(
                            value: shelf['id'] as int,
                            child: Text(shelf['name'] as String),
                          );
                        }).toList(),
                        onChanged: (int? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _shelfId = newValue;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Date Selection
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            readOnly: true,
                            onTap: () => _selectDate(context, true),
                            controller: TextEditingController(
                              text: _dateStarted == null
                                  ? ''
                                  : DateFormat(
                                      'MMM d, y',
                                    ).format(_dateStarted!),
                            ),
                            decoration: filledFieldDecoration(theme).copyWith(
                              labelText: 'Start Date',
                              suffixIcon: _dateStarted != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: _clearStartDate,
                                    )
                                  : const Icon(Icons.calendar_today),
                            ),
                            onTapOutside: (event) {
                              FocusManager.instance.primaryFocus?.unfocus();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            readOnly: true,
                            onTap: () => _selectDate(context, false),
                            controller: TextEditingController(
                              text: _dateFinished == null
                                  ? ''
                                  : DateFormat(
                                      'MMM d, y',
                                    ).format(_dateFinished!),
                            ),
                            decoration: filledFieldDecoration(theme).copyWith(
                              labelText: 'Finish Date',
                              suffixIcon: _dateFinished != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: _clearFinishDate,
                                    )
                                  : const Icon(Icons.calendar_today),
                            ),
                            onTapOutside: (event) {
                              FocusManager.instance.primaryFocus?.unfocus();
                            },
                          ),
                        ),
                      ],
                    ),

                    // Rating
                    const SizedBox(height: 16),
                    if (_useStarRating) ...[
                      Text('Rating', style: theme.textTheme.bodyMedium),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: _useStarRating
                              ? RatingBar.builder(
                                  initialRating: _rating ?? 0,
                                  minRating: 0,
                                  direction: Axis.horizontal,
                                  allowHalfRating: true,
                                  itemCount: 5,
                                  itemSize: 32,
                                  itemPadding: const EdgeInsets.symmetric(
                                    horizontal: 4.0,
                                  ),
                                  itemBuilder: (context, _) => const Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFFBCB04),
                                  ),
                                  glow: false,
                                  onRatingUpdate: (rating) {
                                    setState(() {
                                      _rating = rating;
                                    });
                                  },
                                )
                              : TextField(
                                  controller: _ratingController,
                                  decoration: filledFieldDecoration(theme).copyWith(
                                    labelText: 'Rating',
                                    hintText: 'Enter rating (0–5)',
                                    suffixIcon:
                                        _ratingController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              setState(() {
                                                _rating = null;
                                                _ratingController.clear();
                                              });
                                            },
                                          )
                                        : null,
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d{0,1}(\.\d{0,2})?$'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value.isEmpty) {
                                      setState(() {
                                        _rating = null;
                                      });
                                    } else {
                                      final parsed = double.tryParse(value);
                                      if (parsed != null) {
                                        if (parsed > 5.0) {
                                          _rating = 5.0;
                                          _ratingController.text = '5.00';
                                          _ratingController.selection =
                                              TextSelection.fromPosition(
                                                const TextPosition(offset: 4),
                                              );
                                        } else {
                                          _rating = parsed;
                                        }
                                        setState(() {});
                                      }
                                    }
                                  },
                                  onTapOutside: (event) {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                  },
                                ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: Icon(
                            _isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: _isFavorite
                                ? Colors.red
                                : theme.colorScheme.onSurface.withAlpha(153),
                            size: 32,
                          ),
                          onPressed: () {
                            setState(() {
                              _isFavorite = !_isFavorite;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // User Review
                    TextField(
                      controller: _userReviewController,
                      decoration: filledFieldDecoration(theme).copyWith(
                        labelText: 'Review',
                        hintText: 'Write your thoughts on this book...',
                        alignLabelWithHint: true,
                        suffixIcon: _userReviewController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => setState(
                                  () => _userReviewController.clear(),
                                ),
                              )
                            : null,
                      ),
                      minLines: 2,
                      maxLines: null,
                      onChanged: (_) => setState(() {}),
                      onTapOutside: (event) {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                    ),
                    const SizedBox(height: 16),

                    // Price paid, for readers who track their spending
                    if (widget.settingsViewModel.spendingEnabledNotifier.value)
                      _buildPriceField(theme),

                    // Tags Section
                    InkWell(
                      onTap: () async {
                        final result = await showTagSelectorSheet(
                          context: context,
                          initialSelectedTagIds: _selectedTagIds,
                          tagRepository: TagRepository(DatabaseHelper()),
                          settingsViewModel: widget.settingsViewModel,
                        );

                        if (result != null && mounted) {
                          setState(() {
                            _selectedTagIds = result.toSet();
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        constraints: const BoxConstraints(minHeight: 48),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.sell,
                                  size: 18,
                                  color: theme.colorScheme.onSurface.withAlpha(
                                    153,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Tags',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            if (_selectedTagIds.isNotEmpty)
                              FutureBuilder<List<Tag>>(
                                future: _getTagsByIds(_selectedTagIds.toList()),
                                builder: (context, snapshot) {
                                  final tags = snapshot.data ?? [];
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: tags.isEmpty
                                        ? const SizedBox.shrink()
                                        : Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: tags
                                                .map(
                                                  (tag) => Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 5,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: theme
                                                          .colorScheme
                                                          .secondaryContainer,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      tag.name,
                                                      style: theme
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: theme
                                                                .colorScheme
                                                                .onSecondaryContainer,
                                                          ),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (widget.isEditing) _buildAddedDate(theme),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                onPressed:
                    _titleController.text.trim().isEmpty ||
                        _authorController.text.trim().isEmpty
                    ? null
                    : _saveBook,
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(widget.isEditing ? 'Update Book' : 'Save Book'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectPurchaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _datePurchased ?? _dateToday,
      firstDate: DateTime(1900),
      lastDate: _dateToday,
    );
    if (picked != null) setState(() => _datePurchased = picked);
  }

  /// What the reader paid for this copy and when they bought it, side by
  /// side. Both optional; without a date the book counts as bought the day
  /// it was added.
  Widget _buildPriceField(ThemeData theme) {
    final symbol =
        Money.symbol(widget.settingsViewModel.currencyNotifier.value);
    // Digits with up to two decimals, either mark. A keystroke that would
    // break that is dropped rather than clearing what is there.
    final amount = RegExp(r'^\d{0,9}([.,]\d{0,2})?$');

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _pricePaidController,
              decoration: filledFieldDecoration(theme).copyWith(
                labelText: 'Price paid',
                hintText: '0.00',
                prefixText: '$symbol ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (oldValue, newValue) =>
                      amount.hasMatch(newValue.text) ? newValue : oldValue,
                ),
              ],
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              readOnly: true,
              onTap: _selectPurchaseDate,
              controller: TextEditingController(
                text: _datePurchased == null
                    ? ''
                    : DateFormat('MMM d, y').format(_datePurchased!),
              ),
              decoration: filledFieldDecoration(theme).copyWith(
                labelText: 'Bought on',
                suffixIcon: _datePurchased != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () =>
                            setState(() => _datePurchased = null),
                      )
                    : const Icon(Icons.calendar_today),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Small "Added <date>" line shown at the bottom when editing an existing
  // book. date_added is stored by the DB on insert.
  Widget _buildAddedDate(ThemeData theme) {
    final raw = widget.book?['date_added']?.toString();
    final added = (raw == null || raw.isEmpty) ? null : DateTime.tryParse(raw);
    if (added == null) return const SizedBox.shrink();

    final format = widget.settingsViewModel.defaultDateFormatNotifier.value;
    String formatted;
    try {
      formatted = DateFormat(format).format(added);
    } catch (_) {
      formatted = DateFormat('MMM d, yyyy').format(added);
    }
    final time = DateFormat('h:mm a').format(added);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Added $formatted at $time',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _CoverLoadingPlaceholder extends StatefulWidget {
  final double width;
  final double height;
  final ThemeData theme;

  const _CoverLoadingPlaceholder({
    required this.width,
    required this.height,
    required this.theme,
  });

  @override
  State<_CoverLoadingPlaceholder> createState() =>
      _CoverLoadingPlaceholderState();
}

class _CoverLoadingPlaceholderState extends State<_CoverLoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.theme.colorScheme.surfaceContainerHighest;
    final highlight = widget.theme.colorScheme.surfaceContainerHigh;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(base, highlight, _anim.value),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class IsbnInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    final capped = digits.length > 13 ? digits.substring(0, 13) : digits;

    final buffer = StringBuffer();
    for (int i = 0; i < capped.length; i++) {
      if (i == 3 || i == 4 || i == 6) buffer.write('-');
      buffer.write(capped[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Where a book cover is sourced from in the cover-source chooser.
enum _CoverSource { online, gallery, camera }
