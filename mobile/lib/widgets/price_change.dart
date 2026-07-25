import 'package:flutter/material.dart';

/// 涨跌幅指示器
class PriceChange extends StatelessWidget {
  final double change;
  final double changePercent;
  final TextStyle? style;

  const PriceChange({
    super.key,
    required this.change,
    required this.changePercent,
    this.style,
  });

  Color get _color => change >= 0 ? Colors.red : Colors.green;

  @override
  Widget build(BuildContext context) {
    final textStyle = (style ?? Theme.of(context).textTheme.bodyMedium)
        ?.copyWith(color: _color, fontWeight: FontWeight.w600);

    final sign = change >= 0 ? '+' : '';
    return Text(
      '$sign${change.toStringAsFixed(2)} ($sign${changePercent.toStringAsFixed(2)}%)',
      style: textStyle,
    );
  }
}
