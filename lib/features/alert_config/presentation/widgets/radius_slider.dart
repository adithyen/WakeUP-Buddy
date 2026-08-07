import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../data/models/alert_settings.dart';
import '../../providers/alert_config_provider.dart';

class RadiusSlider extends ConsumerWidget {
  const RadiusSlider({super.key});

  static const List<double> _presets = <double>[200, 500, 1000, 2000, 5000];

  double _sliderToRadius(double sliderValue) {
    const double minLog = 2.0;
    const double maxLog = 3.6989700043360187;
    final double logValue = minLog + sliderValue * (maxLog - minLog);
    return pow(10, logValue).toDouble();
  }

  double _radiusToSlider(double radius) {
    const double minLog = 2.0;
    const double maxLog = 3.6989700043360187;
    final double logValue = log(radius) / ln10;
    return ((logValue - minLog) / (maxLog - minLog)).clamp(0.0, 1.0);
  }

  String _formatRadius(double radius) {
    if (radius >= 1000) {
      final double km = radius / 1000;
      return km == km.roundToDouble() ? '${km.toStringAsFixed(0)} km' : '${km.toStringAsFixed(1)} km';
    }

    return '${radius.round()} m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AlertSettings settings = ref.watch(alertConfigProvider);
    final double sliderValue = _radiusToSlider(settings.alertRadiusMeters);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Alert Radius', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppDimensions.md),
        Text(
          'You will be alerted when you are within ${_formatRadius(settings.alertRadiusMeters)} of your stop.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppDimensions.md),
        Slider(
          value: sliderValue,
          onChanged: (double value) {
            ref.read(alertConfigProvider.notifier).setRadius(_sliderToRadius(value));
          },
        ),
        Wrap(
          spacing: AppDimensions.sm,
          runSpacing: AppDimensions.sm,
          children: _presets.map((double preset) {
            final bool selected = (settings.alertRadiusMeters - preset).abs() < 1;
            return ChoiceChip(
              label: Text(_formatRadius(preset)),
              selected: selected,
              onSelected: (_) => ref.read(alertConfigProvider.notifier).setRadius(preset),
            );
          }).toList(growable: false),
        ),
      ],
    );
  }
}