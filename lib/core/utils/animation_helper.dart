import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Reusable animation builders — keeps all animation boilerplate in one place.
class AnimationHelper {
  /// Staggered fade + slide-up entrance.
  /// [index] staggers the delay so list items animate in sequence.
  static Widget staggeredItem({
    required int index,
    required Widget child,
    int baseDelayMs = 40,
    int durationMs = 280,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: durationMs + index * baseDelayMs),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: c),
      ),
      child: child,
    );
  }

  /// Scale-in entrance — for cards / hero widgets.
  static Widget scaleEntrance({
    required Widget child,
    int delayMs = 0,
    int durationMs = 400,
    Curve curve = Curves.easeOutBack,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: durationMs),
      curve: curve,
      builder: (_, v, c) => Transform.scale(scale: v, child: c),
      child: child,
    );
  }

  /// Horizontal shimmer placeholder — used while data loads.
  static Widget shimmerBox({double width = double.infinity, double height = 16, double radius = 8}) {
    return _ShimmerBox(width: width, height: height, radius: radius);
  }
}

class _ShimmerBox extends StatefulWidget {
  final double width, height, radius;
  const _ShimmerBox({required this.width, required this.height, required this.radius});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          color: Color.lerp(
            AppColors.surfaceContainerLow,
            AppColors.surfaceContainerHigh,
            _ctrl.value,
          ),
        ),
      ),
    );
  }
}
