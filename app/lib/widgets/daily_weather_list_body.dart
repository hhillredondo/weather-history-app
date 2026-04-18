import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_settings.dart';
import '../models/daily_weather.dart';
import '../util/units.dart';
import '../util/weather_code.dart';

class DailyWeatherListBody extends StatelessWidget {
  const DailyWeatherListBody({
    super.key,
    required this.days,
    required this.settings,
    required this.footer,
  });

  final List<DailyWeather> days;
  final AppSettings settings;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.yMMMEd();

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: days.length + 1,
      itemBuilder: (context, index) {
        if (index == days.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 24),
            child: footer,
          );
        }
        final d = days[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(dateFmt.format(d.date)),
            subtitle: Text(weatherCodeLabel(d.weatherCode)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatTempRange(d.tempMaxC, d.tempMinC, settings),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${formatPrecipMm(d.precipitationSumMm, settings)} · '
                  '${formatWindKmh(d.windSpeedMaxKmh, settings)} max',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
