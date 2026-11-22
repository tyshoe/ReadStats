import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:read_stats/data/models/book.dart';
import 'package:read_stats/data/models/cover_shape.dart';
import 'package:read_stats/data/models/shelf.dart';
import 'package:read_stats/data/repositories/book_repository.dart';
import 'package:read_stats/data/repositories/series_repository.dart';
import 'package:read_stats/data/repositories/tag_repository.dart';
import 'package:read_stats/data/services/analytics_service.dart';
import 'package:read_stats/data/services/book_search_service.dart';
import 'package:read_stats/data/services/cover_service.dart';
import 'package:read_stats/data/utils/money.dart';
import 'package:read_stats/data/utils/series_title.dart';
import 'package:read_stats/ui/pages/book/book_tag_editor_page.dart';
import 'package:read_stats/ui/pages/book/widgets/added_date_line.dart';
import 'package:read_stats/ui/pages/book/widgets/audiobook_fields.dart';
import 'package:read_stats/ui/pages/book/widgets/book_cover_controller.dart';
import 'package:read_stats/ui/pages/book/widgets/book_cover_picker.dart';
import 'package:read_stats/ui/pages/book/widgets/book_form_fields.dart';
import 'package:read_stats/ui/pages/book/widgets/book_tags_field.dart';
import 'package:read_stats/ui/pages/book/widgets/duplicate_book_dialog.dart';
import 'package:read_stats/ui/pages/book/widgets/edition_row.dart';
import 'package:read_stats/ui/pages/book/widgets/form_date_field.dart';
import 'package:read_stats/ui/pages/book/widgets/isbn_field.dart';
import 'package:read_stats/ui/pages/book/widgets/price_paid_fields.dart';
import 'package:read_stats/ui/pages/book/widgets/print_length_fields.dart';
import 'package:read_stats/ui/pages/book/widgets/rating_favorite_row.dart';
import 'package:read_stats/ui/pages/book/widgets/series_fields.dart';
import 'package:read_stats/ui/pages/book/widgets/title_case_field.dart';
import 'package:read_stats/ui/pages/book_search/edition_picker_page.dart';
import 'package:read_stats/ui/settings_view_model.dart';
import 'package:read_stats/ui/widgets/app_snackbar.dart';

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
  int _shelfId = Shelf.wantToRead;
  List<Map<String, dynamic>> _shelves = [];
  int _selectedBookType = 0;
  DateTime? _dateStarted;
  DateTime? _datePurchased;
  DateTime? _dateFinished;
  late bool _useStarRating;
  Set<int> _selectedTagIds = {};
  bool _titleTitleCaseEnabled = true;
  bool _authorTitleCaseEnabled = true;
  /// The cover: what will be saved, and getting a new one.
  late final BookCoverController _cover = BookCoverController(
    bookId: widget.isEditing ? widget.book!['id'] as int? : null,
    isSaving: () => _isSaving,
  )..addListener(_onCoverChanged);
  bool _isSaving = false;

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
    AnalyticsService.instance.screen(widget.isEditing ? 'book_edit' : 'book_add');
    _useStarRating =
        widget.settingsViewModel.defaultRatingStyleNotifier.value == 0;
    _selectedBookType =
        widget.settingsViewModel.defaultBookTypeNotifier.value - 1;
    _loadShelves();
    SeriesRepository().names().then((names) {
      if (mounted) setState(() => _seriesNames = names);
    });

    _workKey = widget.isEditing
        ? widget.book!['open_library_key'] as String?
        : widget.searchResult?.workKey;
    if (widget.searchResult != null) {
      _prefillFromSearchResult(widget.searchResult!);
    }
    if (widget.coverSettled) _cover.file = widget.initialCover;

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
      _shelfId = (d['shelf_id'] as int?) ?? Shelf.wantToRead;
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
        _cover.shape = shape;
        _cover.shapeChosen = true;
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
        _cover.file = File(widget.book!['cover_path'] as String);
      }
      _cover.shape = (widget.book!['cover_shape'] as int?) ??
          CoverShape.portrait;
    }
    _shapeFollowsFormat();
  }

  /// Gives a new book the cover shape its format usually has; see
  /// [BookCoverController.followFormat].
  void _shapeFollowsFormat() =>
      _cover.followFormat(_selectedBookType + 1, editing: widget.isEditing);

  void _onCoverChanged() {
    if (mounted) setState(() {});
  }

  /// What the online cover search starts from: the title and author.
  String get _coverQuery => [
    _titleController.text.trim(),
    _authorController.text.trim(),
  ].where((s) => s.isNotEmpty).join(' ');

  Future<void> _loadShelves() async {
    final shelves = await BookRepository().getShelves();
    if (mounted) {
      setState(() {
        _shelves = shelves;
        // Guard: if current shelfId isn't in the loaded list, fall back to first
        if (_shelves.isNotEmpty && !_shelves.any((s) => s['id'] == _shelfId)) {
          _shelfId = Shelf.wantToRead;
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
    _cover.dispose();
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

    final bookRepository = BookRepository();
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
    if (bookExists && !widget.isEditing && !await confirmDuplicateBook(context)) {
      _isSaving = false;
      return;
    }

    // A number without a series means nothing, so it goes with the name.
    final seriesName = _seriesController.text.trim();
    final int? seriesId = seriesName.isEmpty
        ? null
        : await SeriesRepository().idFor(seriesName);
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
      "cover_shape": _cover.shape,
      "open_library_key": _workKey,
    };

    // A cover picked from search or a URL may still be downloading — wait for
    // it here rather than silently saving the book without its image. If it
    // never arrives the book keeps the cover on screen, and the reader is
    // told the new one was lost.
    final coverLoad = _cover.pendingLoad;
    final lostCover = coverLoad != null && !await coverLoad;
    final File? coverFile = _cover.file;

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

        final tagRepo = TagRepository();
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

        if (_cover.changed) {
          if (coverFile != null) {
            final newPath = await CoverService.saveFromPath(
              bookId,
              coverFile.path,
            );
            await bookRepository.updateCoverPath(bookId, newPath);
            await _cover.persistOriginal(bookId);
          } else if (_cover.removed) {
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
          final tagRepo = TagRepository();
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
          await _cover.persistOriginal(newBookId);
        }
      }

      final wasFinished =
          widget.isEditing && widget.book!['shelf_id'] == Shelf.finished;
      // A new book, including a duplicate (which opens prefilled, so
      // isEditing, but without an id).
      if (widget.book?['id'] == null) {
        AnalyticsService.instance
            .bookAdded(method: 'form', bookTypeId: _selectedBookType + 1);
      }
      if (_shelfId == Shelf.finished && !wasFinished) {
        AnalyticsService.instance.bookFinished(bookTypeId: _selectedBookType + 1);
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
        final tags = await TagRepository().getTagsForBook(widget.book!['id']);
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
      _shelfId = Shelf.wantToRead;
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
    if (cover != null && !widget.coverSettled) _cover.loadFromUrl(cover);
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
        await SeriesRepository().existingName(found.name) ??
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
      _cover.loadFromUrl(cover);
    } else if (_cover.file != null || _cover.loading) {
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
    if (_cover.file == null && !_cover.loading && cover != null) {
      await _cover.loadFromUrl(cover);
    }
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
          if (_shelfId == Shelf.wantToRead) {
            _shelfId = Shelf.currentlyReading;
          }
        } else {
          _dateFinished = picked;
          _shelfId = Shelf.finished;
        }
      });
    }
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
                    BookCoverPicker(
                      coverFile: _cover.file,
                      coverShape: _cover.shape,
                      loading: _cover.loading,
                      onTap: _cover.picking
                          ? null
                          : () => _cover.chooseSource(context, _coverQuery),
                      onEdit: () => _cover.edit(context),
                      onRemove: _cover.remove,
                    ),
                    const SizedBox(height: 8),
                    EditionRow(edition: _edition, onTap: _chooseEdition),
                    const SizedBox(height: 16),
                    TitleCaseField(
                      controller: _titleController,
                      label: 'Title',
                      hint: 'Enter book title',
                      titleCase: _titleTitleCaseEnabled,
                      onTitleCaseChanged: (v) =>
                          setState(() => _titleTitleCaseEnabled = v),
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    TitleCaseField(
                      controller: _authorController,
                      label: 'Author',
                      hint: 'Enter author',
                      titleCase: _authorTitleCaseEnabled,
                      onTitleCaseChanged: (v) =>
                          setState(() => _authorTitleCaseEnabled = v),
                      onChanged: () => setState(() {}),
                      suggestions: BookRepository().getAuthorSuggestions,
                    ),
                    const SizedBox(height: 16),
                    SeriesFields(
                      nameController: _seriesController,
                      positionController: _seriesPositionController,
                      nameFocus: _seriesFocus,
                      names: _seriesNames,
                      onNameChanged: () => setState(() {}),
                    ),

                    const Divider(height: 32),

                    // Book Type
                    FormatDropdown(
                      value: _selectedBookType,
                      onChanged: (v) => setState(() {
                        _selectedBookType = v;
                        _shapeFollowsFormat();
                      }),
                    ),
                    const SizedBox(height: 16),

                    // Pages and Words — hidden for audiobooks
                    if (!isAudiobook) ...[
                      PrintLengthFields(
                        pageController: _pageCountController,
                        wordController: _wordCountController,
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Narrator and duration — shown only for audiobooks
                    if (isAudiobook) ...[
                      AudiobookFields(
                        narratorController: _narratorController,
                        hoursController: _durationHoursController,
                        minutesController: _durationMinutesController,
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                    ],

                    IsbnField(
                      controller: _isbnController,
                      // Another ISBN is another edition.
                      onEdited: () => setState(() => _edition = null),
                      onScanned: (isbn) {
                        setState(() {
                          _isbnController.text = isbn;
                          _edition = null;
                        });
                        _lookupByIsbn(isbn);
                      },
                    ),

                    const Divider(height: 32),

                    // Shelf selector
                    if (_shelves.isNotEmpty) ...[
                      ShelfDropdown(
                        shelves: _shelves,
                        value: _shelfId,
                        onChanged: (v) => setState(() => _shelfId = v),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Date Selection
                    Row(
                      children: [
                        Expanded(
                          child: FormDateField(
                            label: 'Start Date',
                            date: _dateStarted,
                            onTap: () => _selectDate(context, true),
                            onClear: () => setState(() => _dateStarted = null),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FormDateField(
                            label: 'Finish Date',
                            date: _dateFinished,
                            onTap: () => _selectDate(context, false),
                            onClear: () => setState(() => _dateFinished = null),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    RatingFavoriteRow(
                      useStars: _useStarRating,
                      rating: _rating,
                      ratingController: _ratingController,
                      onRatingChanged: (r) => setState(() => _rating = r),
                      isFavorite: _isFavorite,
                      onFavoriteToggled: () =>
                          setState(() => _isFavorite = !_isFavorite),
                    ),
                    const SizedBox(height: 16),

                    ReviewField(
                      controller: _userReviewController,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Price paid, for readers who track their spending
                    if (widget.settingsViewModel.spendingEnabledNotifier.value)
                      PricePaidFields(
                        priceController: _pricePaidController,
                        symbol: Money.symbol(
                          widget.settingsViewModel.currencyNotifier.value,
                        ),
                        datePurchased: _datePurchased,
                        onPickDate: _selectPurchaseDate,
                        onClearDate: () =>
                            setState(() => _datePurchased = null),
                      ),

                    BookTagsField(
                      tagIds: _selectedTagIds,
                      onTap: () async {
                        final result = await showTagSelectorSheet(
                          context: context,
                          initialSelectedTagIds: _selectedTagIds,
                          tagRepository: TagRepository(),
                          settingsViewModel: widget.settingsViewModel,
                        );

                        if (result != null && mounted) {
                          setState(() {
                            _selectedTagIds = result.toSet();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    if (widget.isEditing)
                      AddedDateLine(
                        dateAdded: widget.book?['date_added'],
                        format: widget
                            .settingsViewModel
                            .defaultDateFormatNotifier
                            .value,
                      ),
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

}
