import 'dart:io';

import 'package:flutter/material.dart';
import 'package:read_stats/data/models/cover_shape.dart';
import 'package:read_stats/data/services/cover_service.dart';
import 'package:read_stats/ui/pages/book/cover_camera_page.dart';
import 'package:read_stats/ui/pages/book/widgets/book_cover_picker.dart';
import 'package:read_stats/ui/pages/book/widgets/cover_search_sheet.dart';
import 'package:read_stats/ui/widgets/app_snackbar.dart';
import 'package:read_stats/ui/widgets/image_editor_page.dart';

/// The book form's cover: the image it will save, the shape it is framed
/// to, and getting a new one — from the camera, the photo library, an
/// online search or a download — through the crop editor.
///
/// The form sets the starting [file], [shape] and [shapeChosen], listens,
/// and reads [changed], [removed] and [pendingLoad] when it saves.
class BookCoverController extends ChangeNotifier {
  /// The book being edited, whose saved pre-crop original the editor can
  /// reopen. Null for a new book.
  final int? bookId;

  /// Whether the form is saving: a save waiting on a download reports a
  /// failed one itself.
  final bool Function() isSaving;

  BookCoverController({this.bookId, required this.isSaving});

  /// The cover as it will be saved, and the only one the form draws. A cover
  /// from the internet is shown once it has been downloaded, never straight
  /// from its URL: drawing the URL and saving a separate download of it let
  /// the two come apart, so the form could show a cover it didn't save.
  File? file;

  // The full, pre-crop image behind the current cover. The editor re-loads
  // this so the user can always zoom out / reposition against the whole image
  // rather than the already-cropped result. Null when the cover was never run
  // through the editor (an online/search cover is itself already the full
  // image).
  File? _original;

  /// Frames the crop editor and every place the cover is later drawn.
  int shape = CoverShape.portrait;

  /// Whether [shape] is one the reader cropped a cover to. Until it is, a new
  /// book's shape follows its format — see [followFormat].
  bool shapeChosen = false;

  /// The cover differs from the one the book had when the form opened.
  bool changed = false;

  /// True only when the user explicitly removed the cover, which is the only
  /// thing that deletes one: a replacement that fails to download leaves the
  /// existing cover in place.
  bool removed = false;

  /// The cover a picked edition's replaced, so it can be put back; null once
  /// the reader changes the cover any other way. Kept from the first
  /// replacement, so a second edition still goes back to the reader's own.
  ({File? file, File? original, bool changed, bool removed})? replacedFrom;

  /// A cover is being picked from the camera or photo library.
  bool picking = false;

  /// A cover is on its way down.
  bool loading = false;

  // A cover on its way down (search result, edition, online search or ISBN
  // lookup), completing with whether it arrived. A save awaits this so
  // saving quickly can't drop the image.
  Future<bool>? _load;

  // Counts cover changes, so a download that finishes after the reader has
  // moved on to another cover can't put the old one back.
  int _request = 0;
  bool _disposed = false;

  Future<bool>? get pendingLoad => _load;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Gives a new book the cover shape its format usually has — square for an
  /// audiobook — whenever the format is set or changes. Stops once the
  /// reader has cropped a cover to a shape, and never touches a book already
  /// in the library, whose cover was framed for the shape it has. Doesn't
  /// notify: called while the form is already rebuilding.
  void followFormat(int bookTypeId, {required bool editing}) {
    if (editing || shapeChosen) return;
    shape = CoverShape.defaultFor(bookTypeId);
  }

  /// Downloads the cover at [url] and makes it the book's, completing with
  /// whether it arrived. Until then the form keeps showing the cover it had,
  /// under a spinner; if the download fails that cover stays, and the reader
  /// is told. So the cover on screen is always the one a save would store.
  ///
  /// With [undoable] (an edition's cover), the cover it replaces is kept in
  /// [replacedFrom].
  Future<bool> loadFromUrl(String url, {bool undoable = false}) {
    final request = ++_request;
    final load = () async {
      final downloaded = await CoverService.downloadFromUrl(url);
      // The reader chose another cover, or removed it, in the meantime.
      if (_disposed || request != _request) return false;
      loading = false;
      _load = null;
      if (downloaded != null) {
        if (!undoable) {
          replacedFrom = null;
        } else if (replacedFrom == null && file != null) {
          replacedFrom = (
            file: file,
            original: _original,
            changed: changed,
            removed: removed,
          );
        }
        file = downloaded;
        _original = null;
        changed = true;
        removed = false;
      }
      notifyListeners();
      // A save that is waiting on this reports the loss itself.
      if (downloaded == null && !isSaving()) {
        AppSnackbar.show("Couldn't download that cover", isError: true);
      }
      return downloaded != null;
    }();
    _load = load;
    loading = true;
    notifyListeners();
    return load;
  }

  /// Puts back the cover an edition replaced.
  void undoReplace() {
    final before = replacedFrom;
    if (before == null) return;
    replacedFrom = null;
    file = before.file;
    _original = before.original;
    changed = before.changed;
    removed = before.removed;
    _cancelLoad();
    notifyListeners();
  }

  /// The reader took the cover off. Nothing is deleted until the form saves,
  /// so it can be put back: the message offers Undo.
  void remove() {
    replacedFrom = null;
    final before = (
      file: file,
      original: _original,
      changed: changed,
      removed: removed,
    );
    file = null;
    _original = null;
    changed = true;
    removed = true;
    _cancelLoad();
    notifyListeners();
    if (before.file == null) return; // Only a download was stopped.
    AppSnackbar.show(
      'Cover removed',
      actionLabel: 'Undo',
      onAction: () {
        // Gone from the form, or another cover chosen since: leave it.
        if (_disposed || file != null || loading) return;
        file = before.file;
        _original = before.original;
        changed = before.changed;
        removed = before.removed;
        notifyListeners();
      },
    );
  }

  /// Asks where the cover should come from, then fetches it from there.
  /// [searchQuery] starts the online search (the title and author).
  Future<void> chooseSource(BuildContext context, String searchQuery) async {
    final source = await showCoverSourceSheet(context);
    if (source == null || !context.mounted) return;
    switch (source) {
      case CoverSource.online:
        await _searchOnline(context, searchQuery);
      case CoverSource.gallery:
        await _pick(context, (_) => CoverService.pickImage());
      case CoverSource.camera:
        // The in-app camera (back camera by default, with swap/flash
        // controls).
        await _pick(
          context,
          (context) => Navigator.of(context).push<File>(
            MaterialPageRoute(builder: (_) => const CoverCameraPage()),
          ),
        );
    }
  }

  /// Re-open the editor for the current cover so it can be re-cropped or
  /// adjusted. Edits from the full, pre-crop original when one exists — in
  /// this visit, then a previously-saved original on disk — so the user can
  /// zoom back out instead of being stuck with the already-cropped image.
  /// Falls back to the current cover for online covers (already full images)
  /// and legacy pre-original data.
  Future<void> edit(BuildContext context) async {
    File? source = _original;
    if (source == null && bookId != null) {
      source = await CoverService.originalFile(bookId!);
    }
    source ??= file;
    if (source == null || !context.mounted) return;
    await _crop(context, source, recrop: true);
  }

  /// Persist (or clear) the pre-crop original that backs a saved cover.
  Future<void> persistOriginal(int bookId) async {
    if (_original != null) {
      await CoverService.saveOriginalFromPath(bookId, _original!.path);
    } else {
      // The cover is itself a full image (online/unedited); drop any stale
      // original from a previous edit so re-editing uses the current cover.
      await CoverService.deleteOriginal(bookId);
    }
  }

  /// Stops a cover that is downloading from landing: the reader has chosen
  /// something else.
  void _cancelLoad() {
    _request++;
    loading = false;
    _load = null;
  }

  /// Gets an image with [get] and runs it through the crop editor.
  Future<void> _pick(
    BuildContext context,
    Future<File?> Function(BuildContext context) get,
  ) async {
    if (picking) return;
    picking = true;
    notifyListeners();
    try {
      final picked = await get(context);
      if (picked == null || !context.mounted) return;
      await _crop(context, picked);
    } finally {
      if (!_disposed) {
        picking = false;
        notifyListeners();
      }
    }
  }

  /// Runs [source] through the crop editor and, if the reader keeps the
  /// result, makes it the cover, with [source] as its original.
  Future<void> _crop(
    BuildContext context,
    File source, {
    bool recrop = false,
  }) async {
    final shapeBefore = shape;
    final edited = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => ImageEditorPage(
          imageFile: source,
          aspectRatio: CoverShape.aspectRatio(shape),
          coverShape: shape,
          // The editor owns the shape choice — it can show the frame change.
          onCoverShapeChanged: (s) {
            shape = s;
            notifyListeners();
          },
        ),
      ),
    );
    if (_disposed) return;
    if (edited == null) {
      // Cancelled — keep the shape matching the crop that's actually stored.
      shape = shapeBefore;
      notifyListeners();
      return;
    }
    // Re-cropping the edition's cover keeps the way back to the old one;
    // a photo of the reader's own replaces it for good.
    if (!recrop) replacedFrom = null;
    file = edited;
    _original = source;
    shapeChosen = true;
    changed = true;
    removed = false;
    _cancelLoad();
    notifyListeners();
  }

  Future<void> _searchOnline(BuildContext context, String query) async {
    final url = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => CoverSearchSheet(initialQuery: query)),
    );
    if (url == null || _disposed) return;
    await loadFromUrl(url);
  }
}
