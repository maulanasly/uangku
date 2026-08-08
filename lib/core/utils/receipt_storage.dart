import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Moves a receipt image from a temp location to permanent app storage.
///
/// Returns the permanent file path, or null if saving fails.
Future<String?> saveReceiptImage(Uint8List bytes) async {
  try {
    final appDir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory('${appDir.path}/receipts');
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }
    final path = '${receiptsDir.path}/${const Uuid().v4()}.jpg';
    await File(path).writeAsBytes(bytes);
    return path;
  } catch (_) {
    return null;
  }
}

/// Deletes a receipt image file by path. Returns true on success.
Future<bool> deleteReceiptImage(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    return true;
  } catch (_) {
    return false;
  }
}
