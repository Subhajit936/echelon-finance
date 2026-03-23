import 'package:intl/intl.dart';

class NumberFormatter {
  NumberFormatter._();

  static String formatCurrency(double amount, String currency,
      {bool showSign = false}) {
    final formatted = currency == 'INR'
        ? _formatInr(amount.abs())
        : _formatUsd(amount.abs());

    if (showSign) {
      final sign = amount >= 0 ? '+' : '-';
      return '$sign$formatted';
    }
    if (amount < 0) return '-$formatted';
    return formatted;
  }

  static String _formatInr(double amount) {
    // Indian numbering: lakhs and crores
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: amount >= 100 ? 0 : 2,
    );
    return formatter.format(amount);
  }

  static String _formatUsd(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: amount >= 100 ? 0 : 2,
    );
    return formatter.format(amount);
  }

  static String formatCompact(double amount, String currency) {
    final symbol = currency == 'INR' ? '₹' : '\$';
    if (amount >= 10000000) return '$symbol${(amount / 10000000).toStringAsFixed(1)}Cr';
    if (amount >= 100000) return '$symbol${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '$symbol${(amount / 1000).toStringAsFixed(1)}K';
    return formatCurrency(amount, currency);
  }

  static String formatPercent(double value, {int decimals = 1}) {
    return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(decimals)}%';
  }
}
