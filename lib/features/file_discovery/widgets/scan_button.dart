import 'package:flutter/material.dart';

/// Starts a scan and shows progress while one is running.
class ScanButton extends StatelessWidget {
  const ScanButton({super.key, required this.isScanning, required this.onScan});

  final bool isScanning;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isScanning ? null : onScan,
      icon: isScanning
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.search),
      label: Text(isScanning ? 'Scanning' : 'Scan'),
    );
  }
}
