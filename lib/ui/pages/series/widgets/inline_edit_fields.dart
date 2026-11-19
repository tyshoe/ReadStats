import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:read_stats/domain/series_progress.dart';

/// A book's number, edited in place. Commits when the field loses focus or
/// the keyboard's done key is pressed — and only if it changed.
class InlineNumberField extends StatefulWidget {
  final double? value;

  /// An empty field means "no number" rather than "put it back".
  final bool allowEmpty;
  final ValueChanged<double?> onCommit;

  const InlineNumberField({
    super.key,
    required this.value,
    required this.onCommit,
    this.allowEmpty = false,
  });

  @override
  State<InlineNumberField> createState() => _InlineNumberFieldState();
}

class _InlineNumberFieldState extends State<InlineNumberField> {
  late final _controller = TextEditingController(text: _text(widget.value));
  final _focus = FocusNode();

  static String _text(double? v) =>
      v == null ? '' : SeriesProgress.formatNumber(v);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) {
        // Typing replaces the number rather than adding digits to it — "4"
        // tapped and typed over should become "5", not "54".
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      } else {
        _commit();
      }
    });
  }

  @override
  void didUpdateWidget(InlineNumberField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus) _controller.text = _text(widget.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final raw = _controller.text.trim();
    final n = double.tryParse(raw);
    if (raw.isEmpty && widget.allowEmpty) {
      if (widget.value != null) widget.onCommit(null);
      return;
    }
    if (n == null || n <= 0) {
      _controller.text = _text(widget.value);
      return;
    }
    if (n != widget.value) widget.onCommit(n);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 40,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _focus.unfocus(),
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          hintText: '–',
          isDense: true,
          filled: true,
          fillColor: cs.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: cs.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// A placeholder's title, edited in place. Commits like [InlineNumberField].
class InlineTextField extends StatefulWidget {
  final String value;
  final String hint;
  final ValueChanged<String> onCommit;

  const InlineTextField({
    super.key,
    required this.value,
    required this.hint,
    required this.onCommit,
  });

  @override
  State<InlineTextField> createState() => _InlineTextFieldState();
}

class _InlineTextFieldState extends State<InlineTextField> {
  late final _controller = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _controller.text.trim() != widget.value) {
        widget.onCommit(_controller.text.trim());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: _controller,
      focusNode: _focus,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _focus.unfocus(),
      decoration: InputDecoration(
        hintText: widget.hint,
        isDense: true,
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
