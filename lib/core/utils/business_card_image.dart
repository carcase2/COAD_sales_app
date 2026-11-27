import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 카메라 원본(12MP 등)을 미리보기·OCR에 안전한 JPEG로 줄인다.
class PreparedCardImage {
  const PreparedCardImage({required this.path, required this.bytes});

  final String path;
  final Uint8List bytes;
}

Future<PreparedCardImage> prepareBusinessCardImage(String sourcePath) async {
  final tempDir = await getTemporaryDirectory();
  final target = p.join(
    tempDir.path,
    'card_${DateTime.now().millisecondsSinceEpoch}.jpg',
  );

  File? out;
  try {
    final compressed = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      target,
      quality: 72,
      minWidth: 1280,
      minHeight: 1280,
      format: CompressFormat.jpeg,
    );
    if (compressed != null) {
      out = File(compressed.path);
    }
  } catch (_) {}

  var file = out ?? File(sourcePath);
  var bytes = await file.readAsBytes();

  if (bytes.length > 900 * 1024) {
    try {
      final tighter = p.join(
        tempDir.path,
        'card_s_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final again = await FlutterImageCompress.compressAndGetFile(
        file.path,
        tighter,
        quality: 55,
        minWidth: 1024,
        minHeight: 1024,
        format: CompressFormat.jpeg,
      );
      if (again != null) {
        file = File(again.path);
        bytes = await file.readAsBytes();
      }
    } catch (_) {}
  }

  return PreparedCardImage(path: file.path, bytes: bytes);
}

/// 명함 인식 서버로 올리기 전, 긴 변을 [maxLongEdge]px 이하로 줄인 JPEG.
/// 이미 작으면 다시 인코딩만 한다(PNG·WebP도 JPEG로 통일). 디코드 실패 시 원본 그대로.
/// `compute(resizeCardImageForOcr, bytes)` 로 백그라운드 isolate 에서 호출한다.
Uint8List resizeCardImageForOcr(Uint8List bytes, {int maxLongEdge = 1500}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  final oriented = img.bakeOrientation(decoded);
  final longEdge = oriented.width > oriented.height ? oriented.width : oriented.height;
  final resized = longEdge <= maxLongEdge
      ? oriented
      : oriented.width >= oriented.height
          ? img.copyResize(oriented, width: maxLongEdge, interpolation: img.Interpolation.average)
          : img.copyResize(oriented, height: maxLongEdge, interpolation: img.Interpolation.average);
  return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
}
