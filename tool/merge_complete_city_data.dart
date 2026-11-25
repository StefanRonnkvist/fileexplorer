import 'dart:io';

import 'package:csv_plus/csv_plus.dart';

void main(List<String> arguments) {
  const destinationPath = 'assets/combined_city_data.csv';
  const codec = CsvCodec();

  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/merge_complete_city_data.dart <incoming-csv>\n'
      'Appends the cities of <incoming-csv> to $destinationPath, skipping any\n'
      'that are already present. Both files must share the same headers.',
    );
    exitCode = 64; // Command line usage error.
    return;
  }
  final incomingPath = arguments.single;
  if (!File(incomingPath).existsSync()) {
    stderr.writeln('No such file: $incomingPath');
    exitCode = 66; // Input file does not exist.
    return;
  }

  final destinationFile = File(destinationPath);
  final destinationText = destinationFile.readAsStringSync();
  final destinationRows = codec.decodeWithHeaders(destinationText);
  final incomingRows = codec.decodeWithHeaders(
    File(incomingPath).readAsStringSync(),
  );
  if (destinationRows.isEmpty || incomingRows.isEmpty) {
    throw StateError('Both city data files must contain at least one row.');
  }

  final headers = destinationRows.first.headers;
  if (!_sameHeaders(headers, incomingRows.first.headers)) {
    throw StateError('City data files must use the same headers and order.');
  }

  final seen = {for (final row in destinationRows) _key(row)};
  final additions = <List<Object?>>[];
  var duplicates = 0;
  for (final row in incomingRows) {
    if (!seen.add(_key(row))) {
      duplicates++;
      continue;
    }
    additions.add([for (final header in headers) row[header]]);
  }

  if (additions.isNotEmpty) {
    final separator = destinationText.endsWith('\n') ? '' : '\n';
    destinationFile.writeAsStringSync(
      '$destinationText$separator${codec.encode(additions)}',
    );
  }

  stdout.writeln(
    'Added ${additions.length} cities to $destinationPath; '
    'omitted $duplicates duplicates.',
  );
}

bool _sameHeaders(List<String> first, List<String> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

String _key(CsvRow row) {
  final country = '${row['country']}'.trim().toLowerCase();
  final city = '${row['city']}'.trim().toLowerCase();
  return '$country\u0000$city';
}
