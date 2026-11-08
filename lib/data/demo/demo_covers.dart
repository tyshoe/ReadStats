import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;

/// Covers for the demo library: the real one from Open Library when it can be
/// fetched, otherwise a plain typographic one drawn on device. The app ships
/// no cover artwork either way.
class DemoCovers {
  DemoCovers._();

  /// The real cover from [url], falling back to [render] when there is no URL,
  /// no connection, or the download fails.
  static Future<Uint8List> obtain({
    required String? url,
    required String title,
    required String author,
    required bool square,
  }) async {
    if (url != null) {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200 && response.bodyBytes.length > 1000) {
          return square
              ? await _squared(response.bodyBytes)
              : response.bodyBytes;
        }
      } catch (_) {
        // Offline or slow — the drawn cover stands in.
      }
    }
    return render(title: title, author: author, square: square);
  }

  /// A portrait cover made square, as audiobook covers are: the whole cover
  /// centred on a blurred, darkened enlargement of itself. Cropping instead
  /// would cut off the title.
  static Future<Uint8List> _squared(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final source = (await codec.getNextFrame()).image;
    const side = 600.0;
    final w = source.width.toDouble();
    final h = source.height.toDouble();
    final src = Rect.fromLTWH(0, 0, w, h);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Backdrop: scaled to cover the square, blurred and dimmed.
    final coverScale = side / (w < h ? w : h);
    final backdrop = Rect.fromCenter(
      center: const Offset(side / 2, side / 2),
      width: w * coverScale,
      height: h * coverScale,
    );
    canvas.drawImageRect(
      source,
      src,
      backdrop,
      Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, side, side),
      Paint()..color = const Color(0x59000000),
    );

    // The cover itself, whole, with a little margin.
    final fitScale = (side * 0.9) / (w > h ? w : h);
    canvas.drawImageRect(
      source,
      src,
      Rect.fromCenter(
        center: const Offset(side / 2, side / 2),
        width: w * fitScale,
        height: h * fitScale,
      ),
      Paint()..filterQuality = FilterQuality.high,
    );

    final image =
        await recorder.endRecording().toImage(side.toInt(), side.toInt());
    final out = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    source.dispose();
    return out!.buffer.asUint8List();
  }

  static const _width = 400.0;

  static const _palettes = [
    (Color(0xFF1B3A4B), Color(0xFF2E6F8E)),
    (Color(0xFF5B2333), Color(0xFF9E3B4F)),
    (Color(0xFF2D4A22), Color(0xFF5C8A3E)),
    (Color(0xFF3D2B56), Color(0xFF6E4F9E)),
    (Color(0xFF5C3B1E), Color(0xFFB0753A)),
    (Color(0xFF1F2933), Color(0xFF52606D)),
    (Color(0xFF0B4F4A), Color(0xFF1F8A70)),
    (Color(0xFF6B1E1E), Color(0xFFC0392B)),
  ];

  /// PNG bytes for a cover — 2:3, or 1:1 when [square].
  static Future<Uint8List> render({
    required String title,
    required String author,
    required bool square,
  }) async {
    final height = square ? _width : _width * 1.5;
    final size = Size(_width, height);
    final seed = title.codeUnits.fold(0, (a, c) => a + c);
    final (dark, light) = _palettes[seed % _palettes.length];

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [light, dark],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect.deflate(18),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x66FFFFFF),
    );

    final titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(
          color: const Color(0xFFFFFFFF),
          fontSize: square ? 38 : 44,
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 5,
      ellipsis: '…',
    )..layout(maxWidth: _width - 72);
    titlePainter.paint(
      canvas,
      Offset((_width - titlePainter.width) / 2, height * (square ? 0.2 : 0.22)),
    );

    final authorPainter = TextPainter(
      text: TextSpan(
        text: author.toUpperCase(),
        style: const TextStyle(
          color: Color(0xDDFFFFFF),
          fontSize: 20,
          letterSpacing: 2,
          fontWeight: FontWeight.w600,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: _width - 72);
    authorPainter.paint(
      canvas,
      Offset((_width - authorPainter.width) / 2,
          height - 48 - authorPainter.height),
    );

    final image = await recorder
        .endRecording()
        .toImage(_width.toInt(), height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  }
}
