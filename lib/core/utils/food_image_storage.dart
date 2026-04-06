import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';

class FoodImageStorage {
  static const _dirName = 'food_images';

  static Future<Directory> _ensureDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/$_dirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Save image from raw bytes.
  static Future<String> saveImageBytes(Uint8List bytes, {String ext = 'jpg'}) async {
    final dir = await _ensureDir();
    final filename = '${IdGenerator.getUniqueID()}.$ext';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Save image by copying from a source file path (e.g. from image picker).
  /// Preserves the original file extension.
  static Future<String> saveImageFromPath(String sourcePath) async {
    final dir = await _ensureDir();
    final ext = p.extension(sourcePath).replaceAll('.', '');
    final filename = '${IdGenerator.getUniqueID()}.${ext.isNotEmpty ? ext : 'jpg'}';
    final dest = File('${dir.path}/$filename');
    await File(sourcePath).copy(dest.path);
    return dest.path;
  }

  static bool isLocalPath(String? path) {
    if (path == null || path.isEmpty) return false;
    return !path.startsWith('http');
  }
}
