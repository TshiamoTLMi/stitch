import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'kv_store_base.dart';

/// Atomic file-backed store for Android/iOS/desktop.
///
/// Writes go to `<key>.tmp` and are then renamed over the target, so a crash
/// mid-write can never leave a half-written store behind.
class FileKvStore implements KvStore {
  FileKvStore({Future<Directory> Function()? directoryProvider})
      : _directoryProvider =
            directoryProvider ?? getApplicationDocumentsDirectory;

  static const String tempSuffix = '.tmp';

  final Future<Directory> Function() _directoryProvider;

  Future<File> targetFile(String key) async {
    final dir = await _directoryProvider();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}$key');
  }

  @override
  Future<String?> read(String key) async {
    final file = await targetFile(key);
    if (!file.existsSync()) return null;
    return file.readAsString();
  }

  @override
  Future<void> write(String key, String value) async {
    final target = await targetFile(key);
    final temp = File('${target.path}$tempSuffix');
    await temp.writeAsString(value, flush: true);
    try {
      await temp.rename(target.path);
    } catch (_) {
      // Windows/Android can refuse rename onto an existing file.
      if (await target.exists()) await target.delete();
      await temp.rename(target.path);
    }
  }

  @override
  Future<void> delete(String key) async {
    final file = await targetFile(key);
    if (await file.exists()) await file.delete();
  }
}

Future<KvStore> createDefaultKvStore() async => FileKvStore();
