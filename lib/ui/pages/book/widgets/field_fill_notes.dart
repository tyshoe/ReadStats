import 'package:flutter/material.dart';

/// What picking an edition did to one field (or a pair, like an audiobook's
/// hours and minutes): what the reader had before and what the edition put
/// there.
class FieldFill {
  final String label;
  final List<TextEditingController> controllers;

  /// The values from before the first edition touched the field, so Undo
  /// goes back to the reader's own data rather than an earlier edition's.
  final List<String> before;
  List<String> filled;

  /// How [before] reads in "was …".
  final String Function(List<String> values) show;

  FieldFill(this.label, this.controllers, this.before, this.filled, this.show);

  bool get added => before.every((v) => v.trim().isEmpty);

  /// Still what the edition put there — the reader hasn't typed over it.
  bool get live {
    for (var i = 0; i < controllers.length; i++) {
      if (controllers[i].text != filled[i]) return false;
    }
    return true;
  }
}

/// The book form's record of what picking an edition added or replaced, so
/// each field can say so and a replaced value can be put back.
class FieldFills {
  final _fills = <TextEditingController, FieldFill>{};

  /// Puts [values] in [controllers], remembering what was there. A field the
  /// value doesn't change gets no note; one already noted keeps its first
  /// "before" while the reader hasn't edited it since.
  void fill(
    String label,
    List<TextEditingController> controllers,
    List<String> values, {
    String Function(List<String> values)? show,
  }) {
    final current = [for (final c in controllers) c.text];
    final existing = _fills[controllers.first];
    final before = existing != null && existing.live ? existing.before : current;
    for (var i = 0; i < controllers.length; i++) {
      controllers[i].text = values[i];
    }
    if (_same(before, values)) {
      _fills.remove(controllers.first);
    } else {
      _fills[controllers.first] = FieldFill(
        label,
        controllers,
        before,
        values,
        show ?? (v) => v.join(' '),
      );
    }
  }

  /// The note for the field [controller] heads, if it's still current.
  FieldFill? of(TextEditingController controller) {
    final fill = _fills[controller];
    return fill != null && fill.live ? fill : null;
  }

  void undo(FieldFill fill) {
    for (var i = 0; i < fill.controllers.length; i++) {
      fill.controllers[i].text = fill.before[i];
    }
    _fills.remove(fill.controllers.first);
  }

  void clear() => _fills.clear();

  static bool _same(List<String> a, List<String> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].trim() != b[i].trim()) return false;
    }
    return true;
  }
}

/// The line under a field an edition changed: "Added from this edition", or
/// "Replaced · was …" with Undo. Hides itself as soon as the reader types
/// over the value.
class FillNote extends StatelessWidget {
  final FieldFills fills;
  final TextEditingController controller;
  final VoidCallback onUndo;

  const FillNote({
    super.key,
    required this.fills,
    required this.controller,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final fill = fills.of(controller);
        if (fill == null) return const SizedBox.shrink();
        return ChangeNote(
          added: fill.added,
          label: fill.label,
          was: fill.added ? null : fill.show(fill.before),
          onUndo: fill.added
              ? null
              : () {
                  fills.undo(fill);
                  onUndo();
                },
        );
      },
    );
  }
}

/// One "added" or "replaced" line, also used under the cover.
class ChangeNote extends StatelessWidget {
  final bool added;
  final String label;

  /// The old value, for a replaced field; empty or null shows no "was".
  final String? was;
  final VoidCallback? onUndo;

  const ChangeNote({
    super.key,
    required this.added,
    required this.label,
    this.was,
    this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final previous = was?.trim() ?? '';
    final text = added
        ? '$label added from this edition'
        : previous.isEmpty
        ? '$label replaced'
        : '$label replaced · was $previous';
    // Replaced is the one worth checking, so it gets amber — "look here",
    // not red's "something's wrong" — toned for the theme like the accent.
    final mark = added
        ? theme.colorScheme.primary
        : ColorScheme.fromSeed(
            seedColor: Colors.amber,
            brightness: theme.brightness,
          ).primary;
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 4),
      child: Row(
        children: [
          Icon(
            added ? Icons.add_circle : Icons.change_circle,
            size: 14,
            color: mark,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onUndo != null)
            TextButton(
              onPressed: onUndo,
              style: TextButton.styleFrom(
                foregroundColor: mark,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
              child: const Text('Undo'),
            ),
        ],
      ),
    );
  }
}
