import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class PulsingMicButton extends StatefulWidget {
  final bool isListening;
  final VoidCallback onTap;

  const PulsingMicButton({
    super.key,
    required this.isListening,
    required this.onTap,
  });

  @override
  State<PulsingMicButton> createState() => _PulsingMicButtonState();
}

class _PulsingMicButtonState extends State<PulsingMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0.8, end: 1.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(PulsingMicButton old) {
    super.didUpdateWidget(old);
    if (widget.isListening) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (_, __) => SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing rings
              if (widget.isListening)
                ...List.generate(2, (i) => Container(
                  width: 64 + _animation.value * (12 + i * 8),
                  height: 64 + _animation.value * (12 + i * 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.05 - i * 0.01),
                  ),
                )),
              // Core button
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.isListening
                        ? [AppColors.tertiary, AppColors.tertiaryContainer]
                        : [AppColors.primary, AppColors.primaryContainer],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.isListening ? AppColors.tertiary : AppColors.primary)
                          .withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  widget.isListening ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
