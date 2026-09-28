import 'dart:convert';
import 'dart:io';

String stripJsonc(String raw) {
  final buffer = StringBuffer();
  var inString = false;
  var escaped = false;

  for (var i = 0; i < raw.length; i++) {
    final ch = raw[i];

    if (inString) {
      buffer.write(ch);
      if (escaped) {
        escaped = false;
      } else if (ch == '\\') {
        escaped = true;
      } else if (ch == '"') {
        inString = false;
      }
      continue;
    }

    if (ch == '"') {
      inString = true;
      buffer.write(ch);
      continue;
    }

    if (ch == '/' && i + 1 < raw.length) {
      final next = raw[i + 1];
      if (next == '/') {
        while (i + 1 < raw.length && raw[i] != '\n') {
          i++;
        }
        continue;
      }
      if (next == '*') {
        i += 2;
        while (i + 1 < raw.length && !(raw[i] == '*' && raw[i + 1] == '/')) {
          i++;
        }
        i++;
        continue;
      }
    }

    if (ch == ',') {
      var j = i + 1;
      while (j < raw.length && raw[j].trim().isEmpty) {
        j++;
      }
      if (j < raw.length && (raw[j] == '}' || raw[j] == ']')) {
        continue;
      }
    }

    buffer.write(ch);
  }

  return buffer.toString();
}

dynamic mergeJson(dynamic left, dynamic right) {
  if (left == null) return right;
  if (right == null) return left;

  if (left is Map && right is Map) {
    final merged = <String, dynamic>{};

    for (final entry in left.entries) {
      merged[entry.key.toString()] = entry.value;
    }

    for (final entry in right.entries) {
      final key = entry.key.toString();
      if (merged.containsKey(key)) {
        merged[key] = mergeJson(merged[key], entry.value);
      } else {
        merged[key] = entry.value;
      }
    }

    return merged;
  }

  if (left is List && right is List) {
    final merged = <dynamic>[];
    final seen = <String>{};

    for (final item in [...left, ...right]) {
      final signature = jsonEncode(item);
      if (!seen.contains(signature)) {
        seen.add(signature);
        merged.add(item);
      }
    }

    return merged;
  }

  return right;
}

Future<void> main() async {
  final root = Directory('assets');
  final grouped = <String, List<File>>{};

  if (!root.existsSync()) {
    stderr.writeln('Assets directory not found.');
    exitCode = 64;
    return;
  }

  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is File && entity.path.toLowerCase().endsWith('.json')) {
      final basename = entity.uri.pathSegments.isEmpty
          ? entity.path.split(Platform.pathSeparator).last
          : entity.uri.pathSegments.last;
      grouped.putIfAbsent(basename, () => <File>[]).add(entity);
    }
  }

  final outDir = Directory('test');
  outDir.createSync(recursive: true);

  final duplicateNames =
      grouped.entries
          .where((entry) => entry.value.length > 1)
          .map((entry) => entry.key)
          .toList()
        ..sort();

  for (final name in duplicateNames) {
    var merged = <String, dynamic>{};
    final files = grouped[name]!..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      final raw = await file.readAsString();
      final sanitized = stripJsonc(raw);
      final decoded = jsonDecode(sanitized);

      if (decoded is Map) {
        merged = Map<String, dynamic>.from(mergeJson(merged, decoded) as Map);
      } else {
        merged = Map<String, dynamic>.from(
          mergeJson(merged, {'value': decoded}) as Map,
        );
      }
    }

    final outFile = File('${outDir.path}${Platform.pathSeparator}$name');
    await outFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(merged),
    );
    stdout.writeln('Created ${outFile.path}');
  }
}
