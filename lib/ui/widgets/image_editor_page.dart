import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '/data/database/database_helper.dart';

/// Full-screen crop editor. The user pans, pinch-zooms and rotates the image
/// inside a fixed-[aspectRatio] frame, and the framed region is captured on
/// confirm. Used for book covers (2:3 portrait) and the profile avatar (1:1
/// with a circular guide).
///
/// Takes a temporary [imageFile] and returns the edited image as a new
/// temporary [File] via [Navigator.pop], or null if the user cancels.
///
/// [circleMask] only changes the on-screen guide — the capture stays the full
/// square so the saved file can be a JPEG (no alpha) and the display widget
/// does the clipping.
class ImageEditorPage extends StatefulWidget {
  final File imageFile;

  /// Frame width / height the editor opens at. 2/3 for covers, 1 for avatars.
  /// When [onCoverShapeChanged] is supplied the user can switch it in-editor.
  final double aspectRatio;

  /// The cover shape the frame starts on — see DatabaseHelper.coverShapeX.
  final int? coverShape;

  /// Supplying this puts a Standard/Square switch in the editor and reports
  /// the choice as it changes. Null (avatars, anywhere with a fixed frame)
  /// leaves the switch out entirely.
  final ValueChanged<int>? onCoverShapeChanged;

  /// Draw a circular guide instead of rule-of-thirds lines.
  final bool circleMask;

  final String title;

  /// Filename stem for the exported temporary file.
  final String outputPrefix;

  const ImageEditorPage({
    super.key,
    required this.imageFile,
    this.aspectRatio = 2 / 3,
    this.coverShape,
    this.onCoverShapeChanged,
    this.circleMask = false,
    this.title = 'Adjust cover',
    this.outputPrefix = 'edited_cover',
  });

  @override
  State<ImageEditorPage> createState() => _ImageEditorPageState();
}

class _ImageEditorPageState extends State<ImageEditorPage> {
  final GlobalKey _boundaryKey = GlobalKey();

  // Transform applied to the image within the frame, composed in frame space.
  // Pan + zoom only. Rotation is deliberately kept out of the pinch gesture so
  // zooming never tilts the image; it lives in [_quarterTurns] / [_fineRotation]
  // and is only adjustable from the pinned rotate bar.
  Matrix4 _matrix = Matrix4.identity();
  Matrix4 _startMatrix = Matrix4.identity();
  Offset _startFocal = Offset.zero;

  // Rotation, applied about the frame centre. Quarter turns come from the 90°
  // button; the slider adds a fine tilt of +/- [_fineRotationRange].
  int _quarterTurns = 0;
  double _fineRotation = 0;
  static const double _fineRotationRange = 0.7853981633974483; // pi/4 (45°)

  // The reposition hint fades out once the user first touches the image.
  bool _showHint = true;

  // Editable tilt (degrees) field, kept in sync with the ruler both ways.
  final TextEditingController _degController = TextEditingController(text: '0');
  final FocusNode _degFocus = FocusNode();

  // Frame geometry, recomputed each build and read back by the capture step.
  Size _frameSize = Size.zero;

  // The frame's aspect ratio and the shape it came from. Both move when the
  // user switches shape, so the crop that gets captured is the one on screen.
  late double _aspect;
  late int _shape;

  // The image's intrinsic pixel size, and the size it is laid out at inside the
  // frame (scaled to cover, so at least one axis overflows). Panning is clamped
  // against [_displaySize], not the frame — otherwise the overflowing edges of
  // the photo could never be brought into view.
  Size? _imageSize;
  Size _displaySize = Size.zero;

  bool _isSaving = false;

  static const double _deg2rad = 3.1415926535897932 / 180;
  static const double _rad2deg = 180 / 3.1415926535897932;

  @override
  void initState() {
    super.initState();
    _aspect = widget.aspectRatio;
    _shape = widget.coverShape ?? DatabaseHelper.coverShapePortrait;
    // On losing focus, snap the field text back to the (clamped) value.
    _degFocus.addListener(() {
      if (!_degFocus.hasFocus) setState(() {});
    });
    _loadImageSize();
  }

  /// Read the intrinsic dimensions so the frame can lay the image out at its
  /// true aspect ratio. Until this resolves the frame shows a spinner.
  Future<void> _loadImageSize() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final image = await decodeImageFromList(bytes);
      if (!mounted) return;
      setState(() {
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
      });
    } catch (_) {
      // Leave [_imageSize] null; the frame keeps showing its placeholder.
    }
  }

  @override
  void dispose() {
    _degController.dispose();
    _degFocus.dispose();
    super.dispose();
  }

  String _fmtDeg(double deg) {
    if (deg == 0) return '0';
    return deg == deg.roundToDouble()
        ? deg.toStringAsFixed(0)
        : deg.toStringAsFixed(1);
  }

  void _onDegInput(String s) {
    final v = double.tryParse(s);
    if (v == null) return;
    final maxDeg = _fineRotationRange * _rad2deg;
    setState(() => _fineRotation = v.clamp(-maxDeg, maxDeg) * _deg2rad);
  }

  double get _totalRotation =>
      _quarterTurns * 1.5707963267948966 + _fineRotation; // pi/2 per turn

  /// The full transform for the image: rotation about the frame centre, then
  /// the pan/zoom matrix in screen space.
  Matrix4 get _renderTransform {
    final c = Offset(_frameSize.width / 2, _frameSize.height / 2);
    final rot = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..rotateZ(_totalRotation)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
    return _matrix.multiplied(rot);
  }

  void _onScaleStart(ScaleStartDetails d) {
    _startMatrix = _matrix.clone();
    _startFocal = d.localFocalPoint;
    if (_showHint) setState(() => _showHint = false);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final focal = d.localFocalPoint;
    // Incremental pan/zoom in screen space around the focal point. No rotation:
    // pinching only scales and moves the image.
    final delta = Matrix4.identity()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(d.scale, d.scale, 1, 1)
      ..translateByDouble(-_startFocal.dx, -_startFocal.dy, 0, 1);
    setState(() => _matrix = _clampToCover(delta.multiplied(_startMatrix)));
  }

  /// Keep the image filling the frame: never smaller than cover scale, and
  /// never panned far enough to expose a gap. [_matrix] carries only uniform
  /// scale + translation (rotation is handled separately), so it decomposes
  /// directly. Rotation can still reveal corners; this covers the zoom/pan case.
  ///
  /// The image is laid out centred at [_displaySize], which overflows the frame
  /// on the axis the aspect ratios disagree on. Bounds are derived from that
  /// rect so the whole photo stays reachable — clamping against the frame alone
  /// would pin an off-ratio image to its centre crop.
  Matrix4 _clampToCover(Matrix4 m) {
    double s = m.storage[0];
    double tx = m.storage[12];
    double ty = m.storage[13];
    if (s < 1.0) s = 1.0;
    if (_displaySize.isEmpty) {
      return Matrix4.identity()
        ..scaleByDouble(s, s, 1, 1)
        ..setTranslationRaw(tx, ty, 0);
    }
    // Where the centred image's top-left lands once scaled, and how far it can
    // travel before an edge crosses into the frame.
    final originX = s * (_frameSize.width - _displaySize.width) / 2;
    final originY = s * (_frameSize.height - _displaySize.height) / 2;
    tx = _clampAxis(
        tx, _frameSize.width - s * _displaySize.width - originX, -originX);
    ty = _clampAxis(
        ty, _frameSize.height - s * _displaySize.height - originY, -originY);
    return Matrix4.identity()
      ..scaleByDouble(s, s, 1, 1)
      ..setTranslationRaw(tx, ty, 0);
  }

  /// Clamp deliberately avoiding [num.clamp]: on the axis that sets the cover
  /// scale the bounds collapse to 0.0 and -0.0, and clamp compares with
  /// [Comparable.compareTo], which orders -0.0 below 0.0 and throws on what is
  /// really an empty-but-valid range. Degenerate ranges just pin to [upper].
  double _clampAxis(double v, double lower, double upper) =>
      math.min(math.max(v, lower), upper);

  void _rotate90() => setState(() => _quarterTurns += 1);

  Future<void> _confirm() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      // Aim for roughly a 1000px-wide export while respecting screen density.
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final pixelRatio = _frameSize.width > 0
          ? (1000 / _frameSize.width).clamp(dpr, 4.0).toDouble()
          : dpr;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/${widget.outputPrefix}_'
        '${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      if (mounted) Navigator.of(context).pop(file);
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
        ),
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          // Reposition hint — sits above the image and fades out once the user
          // starts adjusting.
          AnimatedOpacity(
            opacity: _showHint ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                'Drag to reposition · pinch to zoom',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Largest frame of the requested aspect ratio that fits the
                  // available area.
                  double frameW = constraints.maxWidth;
                  double frameH = frameW / _aspect;
                  if (frameH > constraints.maxHeight) {
                    frameH = constraints.maxHeight;
                    frameW = frameH * _aspect;
                  }
                  _frameSize = Size(frameW, frameH);

                  // Lay the image out at cover scale but let it overflow the
                  // frame instead of being cropped to it, so panning can reach
                  // the edges the initial centre crop hides.
                  final img = _imageSize;
                  if (img != null && !img.isEmpty) {
                    final coverScale =
                        (frameW / img.width) > (frameH / img.height)
                            ? frameW / img.width
                            : frameH / img.height;
                    _displaySize =
                        Size(img.width * coverScale, img.height * coverScale);
                  }

                  return Center(
                    child: SizedBox(
                      width: frameW,
                      height: frameH,
                      child: GestureDetector(
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: _onScaleUpdate,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Captured region — clipped to the frame.
                            RepaintBoundary(
                              key: _boundaryKey,
                              child: ClipRect(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Container(color: cs.surfaceContainerHighest),
                                    if (!_displaySize.isEmpty)
                                      Transform(
                                        transform: _renderTransform,
                                        // OverflowBox centres the oversized
                                        // image and lifts the frame's tight
                                        // constraints; the enclosing ClipRect
                                        // is what trims it to the crop.
                                        child: OverflowBox(
                                          maxWidth: double.infinity,
                                          maxHeight: double.infinity,
                                          child: SizedBox(
                                            width: _displaySize.width,
                                            height: _displaySize.height,
                                            child: Image.file(
                                              widget.imageFile,
                                              fit: BoxFit.fill,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            // Framing guides, drawn on top and excluded from
                            // the capture.
                            IgnorePointer(
                              child: CustomPaint(
                                painter: widget.circleMask
                                    ? _CircleMaskPainter()
                                    : _GridPainter(),
                                size: Size(frameW, frameH),
                              ),
                            ),
                            if (_imageSize == null)
                              const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (widget.onCoverShapeChanged != null) _buildShapeBar(cs),
          _buildRotateBar(cs),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: FilledButton(
                // Blocked until the image resolves, otherwise Done would
                // capture an empty frame.
                onPressed: (_isSaving || _imageSize == null) ? null : _confirm,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _isSaving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onPrimary,
                        ),
                      )
                    : const Text('Done'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Rotation controls pinned to the bottom: a 90° quarter-turn button and a
  /// draggable fine-tilt ruler with a live degree readout. Dragging the ruler
  /// maps distance to a small angle change, so sub-degree adjustments are easy.
  /// Rotation stays separate from the pinch gesture.
  /// Reshapes the crop frame. The pan/zoom was clamped against the old frame,
  /// so it resets to the centred cover fit — carrying it over could leave a gap
  /// along whichever edge just grew. Rotation belongs to the image, so it stays.
  void _setShape(int shape) {
    if (shape == _shape || _isSaving) return;
    setState(() {
      _shape = shape;
      _aspect = DatabaseHelper.coverAspectRatio(shape);
      _matrix = Matrix4.identity();
    });
    widget.onCoverShapeChanged!(shape);
  }

  Widget _buildShapeBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            for (final option in [
              (
                shape: DatabaseHelper.coverShapePortrait,
                label: 'Standard',
                icon: Icons.crop_portrait,
              ),
              (
                shape: DatabaseHelper.coverShapeSquare,
                label: 'Square',
                icon: Icons.crop_square,
              ),
            ])
              Expanded(
                child: GestureDetector(
                  onTap: () => _setShape(option.shape),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _shape == option.shape
                          ? cs.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          option.icon,
                          size: 18,
                          color: _shape == option.shape
                              ? cs.onPrimary
                              : cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          option.label,
                          style: TextStyle(
                            fontSize: 13,
                            color: _shape == option.shape
                                ? cs.onPrimary
                                : cs.onSurfaceVariant,
                            fontWeight: _shape == option.shape
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRotateBar(ColorScheme cs) {
    final degrees = _fineRotation * _rad2deg;
    // Mirror ruler/reset/90° changes into the field, but never while the user is
    // typing (that would fight the cursor).
    if (!_degFocus.hasFocus) {
      final t = _fmtDeg(degrees);
      if (_degController.text != t) {
        _degController.value = TextEditingValue(
          text: t,
          selection: TextSelection.collapsed(offset: t.length),
        );
      }
    }
    final tiltColor = _fineRotation == 0 ? cs.onSurfaceVariant : cs.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Perfectly centred degree field with a trailing clear (×).
                _buildDegField(cs, tiltColor),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.rotate_90_degrees_cw_outlined),
                    color: cs.onSurface,
                    tooltip: 'Rotate 90°',
                    onPressed: _isSaving ? null : _rotate90,
                  ),
                ),
              ],
            ),
          ),
          _RotationRuler(
            valueDeg: degrees,
            rangeDeg: _fineRotationRange * _rad2deg,
            onChangedDeg: _isSaving
                ? null
                : (d) => setState(() => _fineRotation = d * _deg2rad),
          ),
        ],
      ),
    );
  }

  /// The editable tilt field, styled like the app's other inputs (filled,
  /// rounded). A fixed height keeps it compact and vertically centred; a spacer
  /// matching the trailing × keeps the number horizontally centred. The ×
  /// resets the tilt to 0.
  Widget _buildDegField(ColorScheme cs, Color tiltColor) {
    final canClear = !_isSaving && _fineRotation != 0;
    return Container(
      width: 96,
      height: 34,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Balances the trailing × so the number sits centred in the box.
          const SizedBox(width: 24),
          Expanded(
            child: TextField(
              controller: _degController,
              focusNode: _degFocus,
              enabled: !_isSaving,
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
              ],
              style: TextStyle(
                color: tiltColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: _onDegInput,
              onSubmitted: (_) => _degFocus.unfocus(),
            ),
          ),
          SizedBox(
            width: 24,
            child: IconButton(
              icon: const Icon(Icons.close, size: 15),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 24, height: 24),
              color: cs.onSurfaceVariant,
              tooltip: 'Reset tilt',
              onPressed: canClear
                  ? () {
                      _degFocus.unfocus();
                      setState(() => _fineRotation = 0);
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// A horizontal, draggable rotation dial: tick marks scroll under a fixed centre
/// needle. Drag distance maps to degrees via [_pxPerDeg], giving fine (sub-
/// degree) control, clamped to +/- [rangeDeg]. Reports values in degrees.
class _RotationRuler extends StatefulWidget {
  final double valueDeg;
  final double rangeDeg;
  final ValueChanged<double>? onChangedDeg;

  const _RotationRuler({
    required this.valueDeg,
    required this.rangeDeg,
    required this.onChangedDeg,
  });

  @override
  State<_RotationRuler> createState() => _RotationRulerState();
}

class _RotationRulerState extends State<_RotationRuler> {
  // Visual tick spacing (wide, spread-out dashes).
  static const double _pxPerDeg = 12;
  // Drag sensitivity — smaller than [_pxPerDeg] so the finger moves the value
  // faster than the ticks would 1:1, without narrowing the dash gaps.
  static const double _dragPxPerDeg = 6;
  int _lastTick = 0;

  void _onStart(DragStartDetails d) => _lastTick = widget.valueDeg.round();

  void _onUpdate(DragUpdateDetails d) {
    final cb = widget.onChangedDeg;
    if (cb == null) return;
    // Drag left rotates clockwise (positive).
    double next = widget.valueDeg - d.delta.dx / _dragPxPerDeg;
    next = next.clamp(-widget.rangeDeg, widget.rangeDeg);
    final tick = next.round();
    if (tick != _lastTick) {
      _lastTick = tick;
      HapticFeedback.selectionClick();
    }
    cb(next);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = widget.onChangedDeg != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: enabled ? _onStart : null,
      onHorizontalDragUpdate: enabled ? _onUpdate : null,
      child: SizedBox(
        height: 64,
        child: CustomPaint(
          painter: _RulerPainter(
            valueDeg: widget.valueDeg,
            rangeDeg: widget.rangeDeg,
            pxPerDeg: _pxPerDeg,
            tickColor: cs.onSurfaceVariant,
            needleColor: cs.primary,
          ),
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final double valueDeg;
  final double rangeDeg;
  final double pxPerDeg;
  final Color tickColor;
  final Color needleColor;

  _RulerPainter({
    required this.valueDeg,
    required this.rangeDeg,
    required this.pxPerDeg,
    required this.tickColor,
    required this.needleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final midY = size.height / 2;
    final tick = Paint()..strokeWidth = 1.5;

    final firstDeg = (valueDeg - cx / pxPerDeg).floor();
    final lastDeg = (valueDeg + cx / pxPerDeg).ceil();
    for (int d = firstDeg; d <= lastDeg; d++) {
      if (d < -rangeDeg || d > rangeDeg) continue;
      final x = cx + (d - valueDeg) * pxPerDeg;
      if (x < 0 || x > size.width) continue;
      final isMajor = d % 5 == 0;
      final isLabeled = d % 10 == 0;
      final h = isMajor ? 20.0 : 11.0;
      tick.color = tickColor.withValues(alpha: isMajor ? 0.85 : 0.4);
      canvas.drawLine(Offset(x, midY - h / 2), Offset(x, midY + h / 2), tick);
      if (isLabeled) {
        final tp = TextPainter(
          text: TextSpan(
            text: '$d',
            style: TextStyle(
              color: tickColor.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, midY + h / 2 + 3));
      }
    }

    // Fixed centre needle marking the current angle.
    final needle = Paint()
      ..color = needleColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, midY - 14), Offset(cx, midY + 14), needle);
  }

  @override
  bool shouldRepaint(covariant _RulerPainter old) =>
      old.valueDeg != valueDeg ||
      old.tickColor != tickColor ||
      old.needleColor != needleColor;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75;

    canvas.drawRect(Offset.zero & size, border);
    for (int i = 1; i < 3; i++) {
      final dx = size.width * i / 3;
      final dy = size.height * i / 3;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), line);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), line);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}

/// Avatar guide: dims everything outside the inscribed circle so the user sees
/// exactly what a [CircleAvatar] will show. Purely an overlay — the capture
/// underneath stays the full square.
class _CircleMaskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.shortestSide / 2;

    final scrim = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect),
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawPath(scrim, Paint()..color = Colors.black.withValues(alpha: 0.5));
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _CircleMaskPainter oldDelegate) => false;
}
