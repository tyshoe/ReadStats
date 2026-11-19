import 'package:flutter/material.dart';

class CoverLoadingPlaceholder extends StatefulWidget {
  final double width;
  final double height;
  final ThemeData theme;

  const CoverLoadingPlaceholder({
    super.key,
    required this.width,
    required this.height,
    required this.theme,
  });

  @override
  State<CoverLoadingPlaceholder> createState() =>
      _CoverLoadingPlaceholderState();
}

class _CoverLoadingPlaceholderState extends State<CoverLoadingPlaceholder>
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
