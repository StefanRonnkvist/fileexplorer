import 'package:flutter/material.dart';

/// In-app instructions for the primary discovery and comparison workflow.
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    const steps = <({IconData icon, String title, String description})>[
      (
        icon: Icons.folder_open,
        title: 'Choose a root location',
        description:
            'Open Settings from the gear icon, type the full path of the folder you want to search, and select Save or Scan now. The default root location is G:\\My Drive.',
      ),
      (
        icon: Icons.search,
        title: 'Discover files',
        description:
            'Select Scan on the Discover tab to search the root location and all of its subfolders. Results appear while the scan runs. A scan stops after 2 minutes and keeps the files found so far.',
      ),
      (
        icon: Icons.filter_alt,
        title: 'Filter the results',
        description:
            'Use the Extensions checkboxes to show or hide file types. Selected extensions are listed first, and files without a suffix appear as (no extension). Your choices are remembered and applied to future scans.',
      ),
      (
        icon: Icons.compare,
        title: 'Compare matching files',
        description:
            'Sorted by File Name lists every visible file, grouped by name regardless of letter case. Expand a group to see each path and select Compare. Files with identical content are combined into one card that lists all of their paths.',
      ),
      (
        icon: Icons.fullscreen,
        title: 'Review and print',
        description:
            'Select Full Screen to show each distinct version side by side. Select Print to open the print dialog, where you can print or save a PDF. Each version starts on a new page. Press Esc or the close button to leave full screen.',
      ),
    ];

    const sections = <({String title, String description})>[
      (
        title: 'Workspace controls',
        description:
            'Drag the dividers to resize a pane. Use the chevrons to collapse or reopen Extensions, Sorted by File Name, and Compare. The bottom scrollbar moves across the full workspace when it is wider than the window. Paths and file contents can be selected and copied.',
      ),
      (
        title: 'Settings',
        description:
            'Display mode switches between System, Dark, and Light and applies immediately. Save stores the root location, and Scan now saves it and starts a scan. Extensions for future scans shows the file types that are currently included. Reset restores the default root location, display mode, and extension choices.',
      ),
      (
        title: 'File access and formats',
        description:
            'File Explorer can scan any local, network, or synced drive that your Windows account can read, such as C:\\ or G:\\My Drive. Folders that cannot be opened are skipped, and symbolic links are not followed. If the root location does not exist, no files are shown. Comparison is intended for text files; unreadable or non-text files show an error instead of content.',
      ),
      (
        title: 'Privacy',
        description:
            'Scanning, comparison, and printing happen on your PC. File paths and file contents are never sent anywhere by the app.',
      ),
      (
        title: 'Information and support',
        description:
            'The Information tab contains a contact form. Enter your name, a valid email address, and a question of at least five characters, then select Send Question. The form sends these details with the app package name, version, platform, orientation, and layout shown on the form. An internet connection is required, and the server response is displayed below the form.',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'File Explorer Help',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Find files with matching names and compare their contents.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                for (final step in steps) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(step.icon, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(step.description),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                const Divider(),
                const SizedBox(height: 16),
                for (final section in sections) ...[
                  Text(
                    section.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(section.description),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
