import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '/data/database/database_helper.dart';

/// A book's cover, drawn in the shape the user framed it in.
///
/// Covers are cropped to their shape on save, so drawing a square cover into a
/// 2:3 box would crop away the art the user deliberately kept. Every place a
/// cover appears goes through here so the two shapes can't drift apart.
class BookCover extends StatelessWidget {
  final String path;

  /// See DatabaseHelper.coverShapePortrait / coverShapeSquare.
  final int? shape;

  /// The cover is laid out to this width; height follows from the shape.
  final double width;

  final double borderRadius;

  const BookCover({
    super.key,
    required this.path,
    required this.shape,
    required this.width,
    this.borderRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.file(
        File(path),
        width: width,
        height: width / DatabaseHelper.coverAspectRatio(shape),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}

/// A cover filling a fixed box that may not match its shape — the library grid,
/// whose cells are all one size.
///
/// The art is drawn whole (never cropped) at the box's full width, centred, on
/// a blurred enlargement of itself. A portrait cover in a portrait box simply
/// fills it, so this costs nothing in the common case.
class BookCoverFill extends StatelessWidget {
  final String path;
  final int? shape;

  /// Drawn behind the blur, for the gap a square cover leaves in a tall box.
  final Widget? fallback;

  const BookCoverFill({
    super.key,
    required this.path,
    required this.shape,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    final image = Image.file(
      file,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => fallback ?? const SizedBox.shrink(),
    );

    if (shape != DatabaseHelper.coverShapeSquare) return image;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Backdrop: the same art blown up and blurred, so the filler always
        // matches the cover's own colours.
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Image.file(
            file,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => fallback ?? const SizedBox.shrink(),
          ),
        ),
        Container(color: Colors.black.withValues(alpha: 0.15)),
        Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}
