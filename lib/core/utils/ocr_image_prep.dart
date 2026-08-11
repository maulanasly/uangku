import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Converts a picked image to a JPEG byte array and writes it to a temp file
/// so OCR backends (which don't support HEIC) can read it from disk.
Future<({String path, Uint8List bytes})> prepareImageForOcr(XFile image) async {
  var bytes = await image.readAsBytes();

  final compressed = await FlutterImageCompress.compressWithList(
    bytes,
    quality: 80,
    format: CompressFormat.jpeg,
  );
  bytes = compressed;

  final tempDir = await getTemporaryDirectory();
  final tempFile = File(
    '${tempDir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.jpg',
  );
  await tempFile.writeAsBytes(bytes);

  return (path: tempFile.path, bytes: bytes);
}
