import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants.dart';
import '../../core/errors.dart';

/// Picks a photo from the camera or gallery. Wrapped so tests can fake it.
abstract interface class PhotoSource {
  /// Returns the local file path, or `null` if the user cancelled.
  Future<String?> pick({required bool fromCamera});
}

/// [PhotoSource] backed by the `image_picker` plugin.
class ImagePickerPhotoSource implements PhotoSource {
  ImagePickerPhotoSource([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pick({required bool fromCamera}) async {
    final file = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      // Downscale early to keep memory low; final compression happens later.
      maxWidth: 2400,
      requestFullMetadata: false,
    );
    return file?.path;
  }
}

/// Prepares a photo for upload.
abstract interface class ImageCompressor {
  /// Returns JPEG bytes under [Limits.maxPhotoBytes] with metadata removed.
  Future<Uint8List> compressForUpload(String path);
}

/// Re-encodes with `flutter_image_compress`.
///
/// Re-encoding with `keepExif: false` drops all EXIF metadata, including the
/// GPS location and device details a phone camera embeds. This is the
/// app's privacy measure for photos (report section 14).
class FlutterImageCompressor implements ImageCompressor {
  const FlutterImageCompressor();

  @override
  Future<Uint8List> compressForUpload(String path) async {
    // Try a normal quality first, then a smaller one if still too large.
    for (final (width, quality) in const [(1600, 80), (1280, 65)]) {
      final bytes = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: width,
        minHeight: width,
        quality: quality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      if (bytes == null) break;
      if (bytes.lengthInBytes < Limits.maxPhotoBytes) return bytes;
    }
    throw const UserFacingException(
      'One of the photos could not be prepared. Try a different photo.',
    );
  }
}
