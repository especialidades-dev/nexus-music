import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '/utils/helper.dart';

/// Method channel backed by the native `FileBridge` on HarmonyOS.
const _fileChannel = MethodChannel('nexus_music/filepicker');

/// True only on the Flutter OHOS engine (all [GetPlatform] flags are false).
/// Kept local to avoid pulling the HarmonyOS audio service into Android/Linux.
bool get isHarmonyOSRuntime {
  try {
    return !GetPlatform.isWeb &&
        !GetPlatform.isAndroid &&
        !GetPlatform.isIOS &&
        !GetPlatform.isMacOS &&
        !GetPlatform.isWindows &&
        !GetPlatform.isLinux;
  } catch (_) {
    return false;
  }
}

/// A folder chosen as download location. On HarmonyOS [uri] can be a
/// `file://docs/...` document URI that must be handled by the native bridge.
class PickedFolder {
  final String uri;
  final String path;
  final String name;
  final bool persisted;

  const PickedFolder({
    required this.uri,
    required this.path,
    required this.name,
    required this.persisted,
  });

  bool get isExternal => isContentFolder(uri);

  String get display {
    if (name.isNotEmpty) return name;
    final trimmed = path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    return trimmed.isEmpty ? uri : trimmed;
  }
}

/// `true` when [value] is a document/content URI instead of a plain path.
bool isContentFolder(String? value) {
  if (value == null || value.isEmpty) return false;
  return value.startsWith('file://') ||
      value.startsWith('content://') ||
      value.startsWith('datashare://');
}

bool isContentFile(String? value) => isContentFolder(value);

/// Opens the system folder picker.
///
/// On HarmonyOS this uses the native `DocumentViewPicker` (FOLDER mode); on the
/// other platforms it falls back to `file_picker`. Returns `null` if cancelled.
Future<PickedFolder?> pickDownloadFolder() async {
  if (!isHarmonyOSRuntime) {
    try {
      final path = await FilePicker.platform
          .getDirectoryPath(dialogTitle: 'Select downloads folder');
      if (path == null || path == '/' || path.isEmpty) return null;
      final segments = path.split('/').where((e) => e.isNotEmpty).toList();
      final name = segments.isEmpty ? path : segments.last;
      return PickedFolder(
        uri: path,
        path: path,
        name: name,
        persisted: true,
      );
    } catch (e) {
      printINFO('pickDownloadFolder (non-ohos) error: $e');
      return null;
    }
  }

  try {
    final res = await _fileChannel.invokeMethod<Map>('pickFolder');
    if (res == null) return null;
    final uri = res['uri'] as String?;
    if (uri == null || uri.isEmpty) return null;
    return PickedFolder(
      uri: uri,
      path: (res['path'] as String?) ?? uri,
      name: (res['name'] as String?) ?? '',
      persisted: (res['persisted'] as bool?) ?? false,
    );
  } on PlatformException catch (e) {
    printINFO('pickDownloadFolder error: ${e.message}');
    return null;
  } catch (e) {
    printINFO('pickDownloadFolder unexpected error: $e');
    return null;
  }
}

/// Revalidates access to a previously picked folder (HarmonyOS only).
Future<bool> folderAccessible(String folderUri) async {
  if (folderUri.isEmpty) return false;
  if (!isHarmonyOSRuntime) {
    try {
      return Directory(folderUri).exists();
    } catch (_) {
      return false;
    }
  }
  try {
    final ok =
        await _fileChannel.invokeMethod<bool>('ensureAccess', {'uri': folderUri});
    return ok ?? false;
  } catch (e) {
    printINFO('folderAccessible error: $e');
    return false;
  }
}

/// Copies a sandbox file into the picked folder. Returns the destination URI
/// (or path on non-OHOS platforms), or `null` if the copy failed.
Future<String?> importFileIntoFolder({
  required String folderUri,
  required String fileName,
  required String srcPath,
}) async {
  if (folderUri.isEmpty) return null;
  if (!isHarmonyOSRuntime) {
    try {
      final dest = '$folderUri/$fileName';
      await File(srcPath).copy(dest);
      return dest;
    } catch (e) {
      printINFO('importFileIntoFolder (non-ohos) error: $e');
      return null;
    }
  }
  try {
    return await _fileChannel.invokeMethod<String>('importFile', {
      'folderUri': folderUri,
      'fileName': fileName,
      'srcPath': srcPath,
    });
  } catch (e) {
    printINFO('importFileIntoFolder error: $e');
    return null;
  }
}

/// Checks whether a downloaded file still exists at [fileUri].
Future<bool> downloadedFileExists(String fileUri) async {
  if (fileUri.isEmpty) return false;
  if (isContentFile(fileUri) && isHarmonyOSRuntime) {
    try {
      final ok =
          await _fileChannel.invokeMethod<bool>('fileExists', {'uri': fileUri});
      return ok ?? false;
    } catch (e) {
      printINFO('downloadedFileExists error: $e');
      return false;
    }
  }
  try {
    return File(fileUri).exists();
  } catch (_) {
    return false;
  }
}

/// Deletes a downloaded file (sandbox path or document URI).
Future<bool> deleteDownloadedFile(String fileUri) async {
  if (fileUri.isEmpty) return false;
  if (isContentFile(fileUri) && isHarmonyOSRuntime) {
    try {
      final ok =
          await _fileChannel.invokeMethod<bool>('removeFile', {'uri': fileUri});
      return ok ?? false;
    } catch (e) {
      printINFO('deleteDownloadedFile error: $e');
      return false;
    }
  }
  try {
    final file = File(fileUri);
    if (await file.exists()) {
      await file.delete();
    }
    return true;
  } catch (e) {
    printINFO('deleteDownloadedFile error: $e');
    return false;
  }
}
