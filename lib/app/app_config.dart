/// Application-wide constants.
class AppConfig {
  const AppConfig._();

  static const String title = 'File Explorer';

  /// How long the boot splash stays on screen.
  static const Duration splashDuration = Duration(seconds: 3);

  /// Endpoint that receives the Information tab contact form.
  static final Uri contactEndpoint = Uri.parse(
    'https://stefanronnkvist.com/contact.php',
  );
}
