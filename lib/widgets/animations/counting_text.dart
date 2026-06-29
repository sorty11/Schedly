import 'package:flutter/material.dart';

class CountingText extends StatelessWidget {
  final num value;
  final String suffix;
  final String prefix;
  final TextStyle? style;
  final Duration duration;
  final bool isPercentage;

  const CountingText({
    super.key,
    required this.value,
    this.suffix = '',
    this.prefix = '',
    this.style,
    this.duration = const Duration(milliseconds: 1500),
    this.isPercentage = false,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<num>(
      tween: Tween<num>(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        String formattedValue;
        if (value is int || (!isPercentage && value.truncateToDouble() == value)) {
          formattedValue = val.toInt().toString();
        } else {
          formattedValue = val.toStringAsFixed(1);
        }
        
        return Text(
          '$prefix$formattedValue$suffix',
          style: style,
        );
      },
    );
  }
}
