import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key, required this.serverUri});

  final Uri serverUri;

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _packageController = TextEditingController(
    text: 'Detecting package name...',
  );
  final TextEditingController _questionController = TextEditingController();

  String? _packageName;
  String? _appVersion;
  String? _buildNumber;

  bool _isSending = false;
  bool _packageDetectionFailed = false;
  String? _serverResponseText;
  bool _serverResponseIsError = false;

  String get _artifactVersion {
    final String version = _appVersion ?? '';
    final String buildNumber = _buildNumber ?? '';

    if (version.isEmpty) {
      return 'Unavailable';
    }

    return buildNumber.isEmpty ? version : '$version (build $buildNumber)';
  }

  String get _platformName {
    if (kIsWeb) {
      return 'Web';
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
  }

  String _layoutName(double width) {
    // These labels are submitted as diagnostics; they do not alter layout.
    if (width >= 1100) {
      return 'Wide window';
    }
    if (width >= 600) {
      return 'Medium window';
    }
    return 'Narrow window';
  }

  @override
  void initState() {
    super.initState();
    _detectPackageInformation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _packageController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _detectPackageInformation() async {
    // Package metadata is authoritative for both display and the identifiers
    // sent to the support endpoint.
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();

      if (!mounted) {
        return;
      }

      setState(() {
        _packageName = packageInfo.packageName;
        _appVersion = packageInfo.version;
        _buildNumber = packageInfo.buildNumber;
        _packageController.text = packageInfo.packageName;
        _packageDetectionFailed = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _packageName = null;
        _packageController.text = 'Unable to detect package name';
        _packageDetectionFailed = true;
      });
    }
  }

  Future<void> _sendContactRequest() async {
    FocusScope.of(context).unfocus();

    final FormState? form = _formKey.currentState;

    if (form == null || !form.validate()) {
      return;
    }

    if (_packageName == null) {
      _showMessage(
        'The package name could not be detected. Try reopening the page.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSending = true;
      _serverResponseText = null;
      _serverResponseIsError = false;
    });

    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final String orientation = mediaQuery.orientation.name;
    final String layout = _layoutName(mediaQuery.size.width);
    final TargetPlatform targetPlatform = defaultTargetPlatform;

    // The existing PHP endpoint expects every field below, including the
    // aabVersion key and platform flags, so they are sent unchanged.
    // The app only ships for Windows.
    final Map<String, String> requestData = {
      'returnName': _nameController.text.trim(),
      'returnEmail': _emailController.text.trim(),
      'packageName': _packageName ?? '',
      'appVersion': _appVersion ?? '',
      'buildNumber': _buildNumber ?? '',
      'aabVersion': _artifactVersion,
      'msixVersion': _artifactVersion,
      'platform': _platformName,
      'isWeb': kIsWeb.toString(),
      'isAndroid': (!kIsWeb && targetPlatform == TargetPlatform.android)
          .toString(),
      'isLinux': (!kIsWeb && targetPlatform == TargetPlatform.linux).toString(),
      'isIOS': (!kIsWeb && targetPlatform == TargetPlatform.iOS).toString(),
      'isWindows': (!kIsWeb && targetPlatform == TargetPlatform.windows)
          .toString(),
      'isMacOS': (!kIsWeb && targetPlatform == TargetPlatform.macOS).toString(),
      'orientation': orientation,
      'layout': layout,
      'question': _questionController.text.trim(),
      'submittedAt': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final http.Response response = await http
          .post(
            widget.serverUri,
            headers: {
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=UTF-8',
              'Accept': 'text/html, text/plain, application/json, */*',
            },
            body: requestData,
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) {
        return;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Retain contact details for follow-up submissions, but clear the
        // successfully delivered question.
        _questionController.clear();
        _setServerResponse(
          response: _buildResponseSummary(response),
          isError: false,
        );

        _showMessage('Your question was sent successfully.', isError: false);
      } else {
        _setServerResponse(
          response: _buildResponseSummary(response),
          isError: true,
        );
        _showMessage(_createServerErrorMessage(response), isError: true);
      }
    } on TimeoutException {
      if (mounted) {
        _setServerResponse(
          response: 'Timeout: The server took too long to respond.',
          isError: true,
        );
        _showMessage(
          'The server took too long to respond. Please try again.',
          isError: true,
        );
      }
    } on http.ClientException catch (error) {
      if (mounted) {
        _setServerResponse(
          response: 'Connection error: ${error.message}',
          isError: true,
        );
        _showMessage(
          'Unable to connect to the server: ${error.message}',
          isError: true,
        );
      }
    } catch (error) {
      if (mounted) {
        _setServerResponse(response: 'Unexpected error: $error', isError: true);
        _showMessage('The question could not be sent: $error', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _setServerResponse({required String response, required bool isError}) {
    if (!mounted) {
      return;
    }

    setState(() {
      _serverResponseText = response;
      _serverResponseIsError = isError;
    });
  }

  String _buildResponseSummary(http.Response response) {
    // Preserve the complete response for the on-screen diagnostic panel.
    final String body = response.body.trim().isEmpty
        ? '(empty response body)'
        : response.body.trim();

    return 'Status: ${response.statusCode}\n$body';
  }

  String _createServerErrorMessage(http.Response response) {
    String responseText = response.body.trim();

    // Snack bars should remain readable even when a server returns an HTML
    // error document; the full body remains available in the response panel.
    if (responseText.length > 200) {
      responseText = '${responseText.substring(0, 200)}...';
    }

    if (responseText.isEmpty) {
      return 'The server returned error ${response.statusCode}.';
    }

    return 'The server returned error ${response.statusCode}: $responseText';
  }

  void _showMessage(String message, {required bool isError}) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your name.';
    }

    if (value.trim().length < 2) {
      return 'The name must contain at least two characters.';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    final String email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Enter your return email.';
    }

    final RegExp emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailPattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  String? _validateQuestion(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your question.';
    }

    if (value.trim().length < 5) {
      return 'The question must contain at least five characters.';
    }

    return null;
  }

  Widget _buildDiagnosticRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final MediaQueryData mediaQuery = MediaQuery.of(context);

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Send a Question',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your contact information and question below.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Return name',
                      hintText: 'Enter your name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    validator: _validateName,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Return email',
                      hintText: 'name@example.com',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _packageController,
                    readOnly: true,
                    enableInteractiveSelection: true,
                    decoration: InputDecoration(
                      labelText: 'Application package name',
                      prefixIcon: const Icon(Icons.apps),
                      suffixIcon:
                          _packageName == null && !_packageDetectionFailed
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                  ),

                  if (_packageDetectionFailed) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Package detection failed.',
                            style: TextStyle(color: colors.error),
                          ),
                        ),
                        TextButton(
                          onPressed: _detectPackageInformation,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'App information',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 6),
                          _buildDiagnosticRow('MSIX version', _artifactVersion),
                          _buildDiagnosticRow('Platform', _platformName),
                          _buildDiagnosticRow(
                            'Orientation',
                            mediaQuery.orientation.name,
                          ),
                          _buildDiagnosticRow(
                            'Layout',
                            _layoutName(mediaQuery.size.width),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _questionController,
                    decoration: const InputDecoration(
                      labelText: 'Question',
                      hintText: 'Describe your question or problem',
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 100),
                        child: Icon(Icons.help_outline),
                      ),
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    minLines: 5,
                    maxLines: 10,
                    maxLength: 3000,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    validator: _validateQuestion,
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _isSending || _packageName == null
                          ? null
                          : _sendContactRequest,
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(_isSending ? 'Sending...' : 'Send Question'),
                    ),
                  ),

                  if (_serverResponseText != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Server Response',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _serverResponseIsError
                              ? colors.error
                              : colors.outline,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: _serverResponseIsError
                            ? colors.errorContainer.withValues(alpha: 0.35)
                            : colors.surfaceContainerHighest.withValues(
                                alpha: 0.35,
                              ),
                      ),
                      child: SelectableText(
                        _serverResponseText!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
