import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ProductImage {
  static const maximumBytes = 5 * 1024 * 1024;
  final Uint8List bytes;
  final String contentType, extension;
  const ProductImage._(this.bytes, this.contentType, this.extension);
  factory ProductImage.fromBytes(Uint8List bytes) {
    if (bytes.length > maximumBytes) {
      throw StateError('Choose an image smaller than 5 MB.');
    }
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return ProductImage._(bytes, 'image/jpeg', 'jpg');
    }
    if (bytes.length >= 8 &&
        [
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
        ].asMap().entries.every((e) => bytes[e.key] == e.value)) {
      return ProductImage._(bytes, 'image/png', 'png');
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return ProductImage._(bytes, 'image/webp', 'webp');
    }
    throw StateError('Choose a JPEG, PNG or WebP image.');
  }
  static Future<ProductImage> read(XFile file) async {
    if (await file.length() > maximumBytes) {
      throw StateError('Choose an image smaller than 5 MB.');
    }
    return ProductImage.fromBytes(await file.readAsBytes());
  }

  Future<String> upload(String folder) async {
    final reference = FirebaseStorage.instance.ref(
      '$folder/${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    await reference.putData(bytes, SettableMetadata(contentType: contentType));
    return reference.getDownloadURL();
  }
}
