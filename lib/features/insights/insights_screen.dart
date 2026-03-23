import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/insights_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../providers/database_provider.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsProvider);
    final currency = ref.watch(currencyProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLow,
        title: Text('Financial Insights', style: AppTextStyles.headlineLg),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () async {
              ref.invalidate(insightsProvider);
              // Refresh AI tips with real category data
              final insights = insightsAsync.valueOrNull;
              if (insights != null) {
                try {
                  final ai = ref.read(aiServiceProvider);
                  final catData = await ref
                      .read(transactionRepoProvider)
                      .getCategoryBreakdown();
                  final tips = await ai.generateInsights(
                    currency: currency,
                    savingsRate: insights.savingsRate,
                    categorySpend: catData,
                    healthScore: insights.healthScore,
                  );
                  // Persist to 24-hour disk cache
                  final storage = ref.read(secureStorageProvider);
                  await storage.write(key: 'ai_tips_cache', value: tips);
                  await storage.write(
                    key: 'ai_tips_cache_ts',
                    value: DateTime.now().millisecondsSinceEpoch.toString(),
                  );
                  ref.read(aiTipsCacheProvider.notifier).state = tips;
                  ref.invalidate(insightsProvider);
                } catch (_) {}
              }
            },
          ),
        ],
      ),
      body: insightsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: AppTextStyles.bodyMd)),
        data: (insights) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          child: Column(
            children: [
              // Savings velocity chart
              _SectionCard(
                title: 'Savings Velocity',
                subtitle: 'Last 6 months',
                child: SizedBox(
                  height: 120,
                  child: insights.savingsVelocity.isEmpty
                      ? Center(child: Text('No data yet', style: AppTextStyles.labelMd))
                      : BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            barTouchData: BarTouchData(enabled: false),
                            titlesData: FlTitlesData(
                              show: true,
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, _) {
                                    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                                    final now = DateTime.now();
                                    final month = DateTime(now.year, now.month - (5 - value.toInt()), 1);
                                    return Text(months[month.month - 1], style: AppTextStyles.labelSm);
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            gridData: const FlGridData(show: false),
                            barGroups: insights.savingsVelocity.asMap().entries.map((e) {
                              final value = e.value;
                              return BarChartGroupData(x: e.key, barRods: [
                                BarChartRodData(
                                  toY: value.abs(),
                                  color: value >= 0 ? AppColors.secondary : AppColors.tertiary,
                                  width: 16,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Spending DNA
                  Expanded(
                    flex: 3,
                    child: _SectionCard(
                      title: 'Spending DNA',
                      child: Column(
                        children: [
                          _DnaRow(
                            label: 'Essential',
                            percent: insights.spendingDna.essentialPercent,
                            color: AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(height: 10),
                          _DnaRow(
                            label: 'Lifestyle',
                            percent: insights.spendingDna.lifestylePercent,
                            color: AppColors.tertiary,
                          ),
                          const SizedBox(height: 10),
                          _DnaRow(
                            label: 'Investments',
                            percent: insights.spendingDna.investmentPercent,
                            color: AppColors.secondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Health Score
                  Expanded(
                    flex: 2,
                    child: _SectionCard(
                      title: 'Health',
                      child: Column(
                        children: [
                          _HealthGauge(score: insights.healthScore),
                          const SizedBox(height: 8),
                          Text(
                            _healthLabel(insights.healthScore),
                            style: AppTextStyles.labelLg.copyWith(
                              color: _healthColor(insights.healthScore),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // AI Smart tips
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Smart Savings Tips',
                          style: AppTextStyles.titleLg.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      insights.aiTips,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _healthLabel(double score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    return 'Needs work';
  }

  Color _healthColor(double score) {
    if (score >= 80) return AppColors.secondary;
    if (score >= 60) return const Color(0xFF6A7A00);
    if (score >= 40) return const Color(0xFF8B5E00);
    return AppColors.tertiary;
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.titleLg),
          if (subtitle != null) Text(subtitle!, style: AppTextStyles.labelMd),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DnaRow extends StatelessWidget {
  final String label;
  final double percent;
  final Color color;

  const _DnaRow({required this.label, required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.labelMd),
            Text('${percent.toStringAsFixed(0)}%',
                style: AppTextStyles.labelMd.copyWith(color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.surfaceContainerHigh,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _HealthGauge extends StatelessWidget {
  final double score;
  const _HealthGauge({required this.score});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(80, 80),
            painter: _HealthGaugePainter(score: score),
          ),
          Text(
            score.toStringAsFixed(0),
            style: AppTextStyles.headlineMd.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _HealthGaugePainter extends CustomPainter {
  final double score;
  _HealthGaugePainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const startAngle = pi * 0.75;
    const sweepAngle = pi * 1.5;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepAngle, false,
      Paint()..color = AppColors.surfaceContainerHigh
            ..strokeWidth = 8
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
    );

    final color = score >= 80 ? AppColors.secondary
        : score >= 60 ? const Color(0xFF6A7A00)
        : AppColors.tertiary;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepAngle * (score / 100).clamp(0, 1), false,
      Paint()..color = color
            ..strokeWidth = 8
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_HealthGaugePainter old) => old.score != score;
}
