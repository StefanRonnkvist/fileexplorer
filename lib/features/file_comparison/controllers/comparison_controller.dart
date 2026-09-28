import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/comparison_entry.dart';
import '../services/content_grouping.dart';

/// Reads the text content of the file at a path.
typedef FileContentReader = Future<String> Function(String path);

Future<String> _readFromDisk(String path) => File(path).readAsString();

/// Loads the files of one name group and exposes their distinct contents.
class ComparisonController extends ChangeNotifier {
  ComparisonController({FileContentReader? reader})
    : _reader = reader ?? _readFromDisk;

  final FileContentReader _reader;

  String? _fileName;
  List<ComparisonEntry> _entries = const <ComparisonEntry>[];
  bool _isLoading = false;
  bool _disposed = false;

  /// Name of the group being compared, or `null` when nothing is selected.
  String? get fileName => _fileName;
  List<ComparisonEntry> get entries => _entries;
  bool get isLoading => _isLoading;

  Future<void> compare(String fileName, List<String> paths) async {
    _fileName = fileName;
    _entries = const <ComparisonEntry>[];
    _isLoading = true;
    _notify();

    final contents = await Future.wait(
      paths.map((path) async {
        try {
          return MapEntry(path, await _reader(path));
        } on Object catch (error) {
          return MapEntry(path, 'Unable to read file as text.\n$error');
        }
      }),
    );
    // Ignore the result if another comparison started or [clear] ran meanwhile.
    if (_disposed || _fileName != fileName) {
      return;
    }
    _entries = groupByContent(contents);
    _isLoading = false;
    _notify();
  }

  void clear() {
    _fileName = null;
    _entries = const <ComparisonEntry>[];
    _isLoading = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
