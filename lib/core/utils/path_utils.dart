/// Label used for files that have no extension.
const String noExtension = '(no extension)';

/// Returns the last segment of [path], accepting `/` and `\` separators.
String fileNameOf(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.substring(normalized.lastIndexOf('/') + 1);
}

/// Returns the lowercase extension of [path] including its dot (`.txt`), or
/// [noExtension].
///
/// Dotfiles such as `.gitignore` and names ending in a dot have no extension.
String extensionOf(String path) {
  final fileName = fileNameOf(path);
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex == fileName.length - 1) {
    return noExtension;
  }
  return fileName.substring(dotIndex).toLowerCase();
}
