import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class SavingsRateGauge extends StatelessWidget {
  final double savingsRate; // 0-100

  const SavingsRateGauge({super.key, required this.savingsRate});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(100, 100),
            painter: _GaugePainter(savingsRate: savingsRate),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${savingsRate.toStringAsFixed(0)}%',
                style: AppTextStyles.headlineMd.copyWith(color: AppColors.secondary),
              ),
              Text('saved', style: AppTextStyles.labelSm),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double savingsRate;
  _GaugePainter({required this.savingsRate});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const startAngle = pi * 0.75;
    const sweepAngle = pi * 1.5;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = AppColors.surfaceContainerHigh
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Progress
    final progress = (savingsRate / 100).clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progress,
      false,
      Paint()
        ..color = AppColors.secondary
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.savingsRate != savingsRate;
}
