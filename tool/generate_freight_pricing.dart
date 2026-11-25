import 'dart:io';

import 'package:csv_plus/csv_plus.dart';

/// Writes `assets/freight_pricing.csv`, the routes tab's freight table, from the
/// freighter ranges in `assets/fleet.csv`.
///
/// The freight table lists one column per freighter the Broker sells, headed by
/// that aircraft's maximum miles, and one rate per column: the shortest-range
/// freighter earns the low rate and the longest-range one the high rate, with
/// the columns between them spaced evenly. This mirrors how the routes tab
/// seeds the table, so running the tool reproduces the shipped asset.
void main(List<String> arguments) {
  const fleetPath = 'assets/fleet.csv';
  const destinationPath = 'assets/freight_pricing.csv';
  const headers = ['max_range', 'rate'];
  const codec = CsvCodec();

  final fleetRows = codec.decodeWithHeaders(File(fleetPath).readAsStringSync());
  if (fleetRows.isEmpty) {
    throw StateError('$fleetPath must contain at least one aircraft.');
  }

  final ranges = <String>[
    for (final row in fleetRows) _maxMiles('${row['range']}'),
  ];
  if (ranges.isEmpty) {
    throw StateError('$fleetPath has no aircraft ranges to price.');
  }

  final rates = _rates(ranges.length);
  final rows = [
    for (final (index, range) in ranges.indexed) [range, '${rates[index]}'],
  ];

  File(destinationPath)
      .writeAsStringSync(const CsvCodec().encode([headers, ...rows]));
  stdout.writeln('Wrote ${rows.length} freight rows to $destinationPath.');
}

/// The rate each column earns: [freightRevenueLow] at the first column and
/// [freightRevenueHigh] at the last, spaced evenly between them.
List<int> _rates(int columnCount) {
  if (columnCount <= 1) return const [freightRevenueLow];
  final step = (freightRevenueHigh - freightRevenueLow) / (columnCount - 1);
  return [
    for (var index = 0; index < columnCount; index++)
      (freightRevenueLow + step * index).round(),
  ];
}

/// The range column header for an aircraft, prefixed the way the price tables
/// show maximum miles (e.g. `>1800`).
String _maxMiles(String range) {
  final trimmed = range.trim();
  return trimmed.isEmpty || trimmed.startsWith('>') ? trimmed : '>$trimmed';
}

/// The freight revenue the shortest-range freighter earns per range column, in
/// whole dollars. Kept in step with `freightRevenueLow` in the routes tab.
const freightRevenueLow = 2268;

/// The freight revenue the longest-range freighter earns per range column, in
/// whole dollars. Kept in step with `freightRevenueHigh` in the routes tab.
const freightRevenueHigh = 7257;
