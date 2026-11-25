import 'dart:io';
import 'dart:math' as math;

import 'package:csv_plus/csv_plus.dart';

void main() {
  const path = 'assets/combined_city_data.csv';
  const minimumDistanceMiles = 100.0;
  const codec = CsvCodec();

  final file = File(path);
  final source = file.readAsStringSync();
  final rows = codec.decodeWithHeaders(source);
  final lineEnding = source.contains('\r\n') ? '\r\n' : '\n';
  final physicalLines = source.split(RegExp(r'\r?\n'));
  final hadTrailingLineEnding = physicalLines.last.isEmpty;
  if (hadTrailingLineEnding) physicalLines.removeLast();
  if (physicalLines.length != rows.length + 1) {
    throw StateError(
      'City CSV must contain exactly one physical line per row.',
    );
  }

  final rankedIndexes = List<int>.generate(rows.length, (index) => index)
    ..sort((first, second) {
      final populationOrder = _population(rows[second])
          .compareTo(_population(rows[first]));
      return populationOrder != 0 ? populationOrder : first.compareTo(second);
    });
  final keptIndexes = <int>[];
  final removedIndexes = <int>{};

  for (final candidateIndex in rankedIndexes) {
    final candidate = rows[candidateIndex];
    final tooClose = keptIndexes.any(
      (keptIndex) =>
          _sameCountry(candidate, rows[keptIndex]) &&
          _distanceMiles(candidate, rows[keptIndex]) < minimumDistanceMiles,
    );
    if (tooClose) {
      removedIndexes.add(candidateIndex);
    } else {
      keptIndexes.add(candidateIndex);
    }
  }

  final outputLines = <String>[
    physicalLines.first,
    for (var index = 0; index < rows.length; index++)
      if (!removedIndexes.contains(index)) physicalLines[index + 1],
  ];
  final output = outputLines.join(lineEnding);
  file.writeAsStringSync(hadTrailingLineEnding ? '$output$lineEnding' : output);

  stdout.writeln(
    'Kept ${keptIndexes.length} cities in $path; '
    'removed ${removedIndexes.length} cities within 100 miles of a '
    'higher-population city in the same country.',
  );
}

bool _sameCountry(CsvRow first, CsvRow second) {
  return '${first['country']}'.trim().toLowerCase() ==
      '${second['country']}'.trim().toLowerCase();
}

int _population(CsvRow row) {
  final value = row['population'];
  if (value is int) return value;
  if (value is num) return value.round();
  final parsed = int.tryParse('$value'.replaceAll(RegExp('[^0-9-]'), ''));
  if (parsed == null) {
    throw FormatException('Invalid population for ${row['city']}.');
  }
  return parsed;
}

double _distanceMiles(CsvRow first, CsvRow second) {
  const earthRadiusMiles = 3958.7613;
  final firstLatitude = _coordinate(first, 'latitude') * math.pi / 180;
  final secondLatitude = _coordinate(second, 'latitude') * math.pi / 180;
  final latitudeDelta = secondLatitude - firstLatitude;
  final longitudeDelta =
      (_coordinate(second, 'longitude') - _coordinate(first, 'longitude')) *
      math.pi /
      180;
  final haversine =
      math.pow(math.sin(latitudeDelta / 2), 2) +
      math.cos(firstLatitude) *
          math.cos(secondLatitude) *
          math.pow(math.sin(longitudeDelta / 2), 2);
  return earthRadiusMiles *
      2 *
      math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
}

double _coordinate(CsvRow row, String field) {
  final value = row[field];
  if (value is num) return value.toDouble();
  final parsed = double.tryParse('$value');
  if (parsed == null) {
    throw FormatException('Invalid $field for ${row['city']}.');
  }
  return parsed;
}
