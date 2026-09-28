# File Explorer

File Explorer is a Windows desktop application, built with Flutter, for finding files with the same name
across a local folder tree and comparing their text contents. It is useful when
projects, backups, or synced directories contain copies of the same
configuration, source, or data file.

## Features

- Recursively scans an accessible root folder and its subfolders, without
	following symbolic links and skipping folders that cannot be opened.
- Shows results while the scan runs and keeps partial results if the
	two-minute limit is reached.
- Groups file names case-insensitively and filters results by extension.
- Compares the text contents and paths of files with the same name.
- Consolidates identical content into one comparison card while retaining
	every source path.
- Shows each distinct version side by side in a full-screen view.
- Prints comparisons or saves them as PDF through the system print dialog.
- Resizable and collapsible workspace panes with horizontal scrolling.
- System, Dark, and Light display modes.
- Persists the root location, display mode, and extension preferences.
- Includes an Information contact form and an in-app Help guide.

## App tabs

### Discover

The main workspace contains three panes:

1. **Extensions** lists the file types found during the scan. Clear an
	extension to hide those files from the results and future scans. Files without
	a suffix appear as **(no extension)**, and selected extensions are listed
	first.
2. **Sorted by File Name** lists every visible file, grouped case-insensitively
	by file name. Expand a group to inspect its paths and select **Compare**.
3. **Compare** displays the paths and contents of every file in the selected
	group. Copies with identical content share one card that lists all source
	paths. Files that cannot be read as text display an error message.
	Select **Full Screen** to view the distinct versions side by side, and
	select **Print** there to open the system print dialog. Each distinct
	version starts on a new page in a monospaced font. Press **Esc** or the
	close button to leave full screen.

Drag the pane dividers to resize the workspace. Use the chevron buttons to
collapse or reopen individual panes, and use the bottom scrollbar when the
workspace is wider than the window.

### Information

Provides an optional **Send a Question** form with a return name (at least two
characters), return email, and question (5–3000 characters). The form also
shows the detected package name and app information (version, platform,
orientation, and layout class). Submitting it sends the entered details along
with the package name, version, build number, platform, orientation, layout
class, and submission time. It requires an internet connection, sends the
request to `https://stefanronnkvist.com/contact.php` with a 20-second timeout,
and displays the server response below the form.

### Help

Explains root locations, scanning and filtering, matching-file comparisons,
full-screen review and printing, workspace controls, settings, file access,
privacy, and support.

### Settings

The gear icon in the app bar opens the settings dialog:

- **Display mode** switches between System, Dark, and Light immediately.
- **Root location** is the folder to scan (default `G:\My Drive`).
- **Extensions for future scans** shows the extensions currently included.
- **Reset** restores the default root location, display mode, and extension
	choices; **Save** stores the root location; **Scan now** saves it and starts
	a scan.

## Getting started

### Requirements

- Windows 10 or later (x64)
- Flutter with a Dart SDK compatible with `^3.12.2` and Windows desktop
	support enabled
- Visual Studio with the **Desktop development with C++** workload
- Read access to the local root folder you want to scan

Install dependencies and run the app:

```sh
flutter pub get
flutter run -d windows
```

File discovery uses the Windows file system directly. Any local drive, network
drive, or synced folder (for example, `G:\My Drive`) that your Windows account
can read can be scanned.

## Usage

1. Open **Settings** from the gear icon in the app bar.
2. Type the full path of the root folder to search.
3. Select **Save**, then open **Discover** and select **Scan**. Alternatively,
	select **Scan now** from Settings.
4. Use **Extensions** to choose the file types to include. These choices are
	remembered for future scans.
5. Expand a file-name group, review its paths, and select **Compare**.
6. Optionally open **Full Screen** and select **Print** to create a PDF.

The recursive scan has a two-minute time limit. If it expires, the app keeps
and displays the files found so far. Choose a more specific root folder and
scan again when you need a smaller result set. If the root folder does not
exist, the scan returns no files.

Scanning and comparison happen locally. File paths and contents are not sent
to the app's contact endpoint. The Information form sends data only when you
submit it.

## Development

Project layout:

- `lib/main.dart` – app shell, settings, and the Discover workspace
- `lib/features/file_discovery/` – recursive file scanner
- `lib/features/file_comparison/` – comparison model, full-screen view, and
	PDF builder
- `lib/features/help/` – Help tab
- `lib/contact/` – Information contact form
- `store_listing/` – Microsoft Store descriptions

Run static analysis and tests with:

```sh
flutter analyze
flutter test
```

Build the Windows release and package it as an MSIX:

```sh
flutter build windows --release
dart run msix:create --build-windows=false
```

MSIX packaging is configured under `msix_config` in `pubspec.yaml`. The
workspace also includes VS Code tasks and PowerShell scripts for release builds
and maintenance.
