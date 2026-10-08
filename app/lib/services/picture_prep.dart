import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

/// A picture ready to be uploaded as a room's puzzle.
class PreparedPicture {
  final Uint8List bytes;
  final int width;
  final int height;

  const PreparedPicture(this.bytes, this.width, this.height);

  double get aspectRatio => width / height;
}

/// Largest upload the server accepts once base64-encoded (see
/// MAX_IMAGE_BASE64 in server/src/index.js).
const int kMaxPictureBytes = 1500 * 1024;

// Longest side and JPEG quality to try, best first. The board never shows
// more than ~1600px of picture, so there is no point starting higher.
const List<(int, int)> _attempts = [
  (1600, 90),
  (1600, 82),
  (1600, 72),
  (1280, 78),
  (1024, 75),
  (800, 70),
  (640, 60),
];

/// Shrinks and re-encodes [source] (any format the platform can decode) so it
/// fits in [maxBytes], keeping as much quality as that allows.
Future<PreparedPicture> preparePicture(Uint8List source, {int maxBytes = kMaxPictureBytes}) async {
  final codec = await ui.instantiateImageCodec(source);
  final full = (await codec.getNextFrame()).image;
  try {
    final longest = full.width > full.height ? full.width : full.height;
    // Already small enough in both senses: send it untouched.
    if (source.length <= maxBytes && longest <= _attempts.first.$1) {
      return PreparedPicture(source, full.width, full.height);
    }

    Uint8List? best;
    var bestWidth = 0, bestHeight = 0;
    int? scaledFor;
    Uint8List? rgba;
    for (final (side, quality) in _attempts) {
      final scale = longest > side ? side / longest : 1.0;
      final width = (full.width * scale).round().clamp(1, full.width);
      final height = (full.height * scale).round().clamp(1, full.height);
      if (scaledFor != side) {
        rgba = await _scaledRgba(full, width, height);
        scaledFor = side;
      }
      final encoded = await compute(_encodeJpeg, (rgba!, width, height, quality));
      best = encoded;
      bestWidth = width;
      bestHeight = height;
      if (encoded.length <= maxBytes) break;
    }
    return PreparedPicture(best!, bestWidth, bestHeight);
  } finally {
    full.dispose();
  }
}

/// Draws [image] at [width] x [height] and returns its RGBA pixels. Going
/// through a canvas keeps the EXIF orientation the decoder already applied.
Future<Uint8List> _scaledRgba(ui.Image image, int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(
    image,
    ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
  final picture = recorder.endRecording();
  final scaled = await picture.toImage(width, height);
  picture.dispose();
  final data = await scaled.toByteData(format: ui.ImageByteFormat.rawRgba);
  scaled.dispose();
  return data!.buffer.asUint8List();
}

Uint8List _encodeJpeg((Uint8List, int, int, int) args) {
  final (rgba, width, height, quality) = args;
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(image, quality: quality);
}
