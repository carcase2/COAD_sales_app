import 'dart:io';
import 'dart:typed_data';
import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/core/utils/attachment_utils.dart';
import 'package:coad_customer_calls/data/app_dependencies.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:minio/minio.dart';
import 'package:intl/intl.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// **B2 직접 업로드 기법** — 인트라넷 서버를 거치지 않고 S3 호환 API로 직접 전송.
class B2UploadRepository {
  B2UploadRepository(AppDependencies _deps);

  Minio? _minioCache;

  Minio _getMinio() {
    if (_minioCache != null) return _minioCache!;

    final endPoint = dotenv.env['B2_S3_ENDPOINT']?.trim() ?? '';
    final accessKey = dotenv.env['B2_S3_KEY_ID']?.trim() ?? '';
    final secretKey = dotenv.env['B2_S3_APP_KEY']?.trim() ?? '';
    final region = dotenv.env['B2_REGION']?.trim() ?? 'us-east-005';

    if (endPoint.isEmpty || accessKey.isEmpty || secretKey.isEmpty) {
      throw ApiException('Backblaze B2 설정이 .env에 누락되었습니다.');
    }

    _minioCache = Minio(
      endPoint: endPoint,
      accessKey: accessKey,
      secretKey: secretKey,
      region: region,
      useSSL: true,
    );
    return _minioCache!;
  }

  /// 이미지인 경우 압축을 수행하고 임시 파일 경로를 반환합니다.
  Future<File> _compressIfNeeded(String originalPath) async {
    if (classifyAttachmentUrl(originalPath) != AttachmentKind.image) {
      return File(originalPath);
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = p.join(
        tempDir.path,
        'compressed_${DateFormat('HHmmss').format(DateTime.now())}_${p.basename(originalPath)}',
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        originalPath,
        targetPath,
        quality: 80,
        minWidth: 1920,
        minHeight: 1080,
      );

      if (result == null) return File(originalPath);
      return File(result.path);
    } catch (e) {
      // 압축 실패 시 원본 반환 (안전 장치)
      return File(originalPath);
    }
  }

  /// 업로드 후 공개 [url] 반환.
  Future<String> uploadSalesCallFile({
    required String filePath,
    required String siteName,
    String? customerPhone,
  }) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(now);
    final fileName = p.basename(filePath);
    final timestamp = now.millisecondsSinceEpoch;

    // 고객 연락처에서 숫자만 추출하여 폴더명으로 사용 (없으면 'unknown')
    final phoneFolder =
        customerPhone?.replaceAll(RegExp(r'[^0-9]'), '') ?? 'unknown';
    final safePhone = phoneFolder.isEmpty ? 'unknown' : phoneFolder;

    // 경로 규칙: sales_calls/연락처/날짜_타임스탬프_파일명
    final objectPath =
        'sales_calls/$safePhone/${dateStr}_${timestamp}_$fileName';
    return _putPublicObject(filePath: filePath, objectPath: objectPath);
  }

  /// 명함 이미지 업로드. 경로: business_cards/작성자/날짜_타임스탬프_파일명
  Future<String> uploadBusinessCardFile({
    required String filePath,
    required String userId,
  }) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(now);
    final fileName = p.basename(filePath);
    final timestamp = now.millisecondsSinceEpoch;
    final safeUser = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final folder = safeUser.isEmpty ? 'unknown' : safeUser;
    final objectPath =
        'business_cards/$folder/${dateStr}_${timestamp}_$fileName';
    return _putPublicObject(filePath: filePath, objectPath: objectPath);
  }

  /// A/S 접수 첨부. 경로: as_calls/연락처/날짜_타임스탬프_파일명
  Future<String> uploadSupportCallFile({
    required String filePath,
    String? customerPhone,
  }) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(now);
    final fileName = p.basename(filePath);
    final timestamp = now.millisecondsSinceEpoch;
    final phoneFolder =
        customerPhone?.replaceAll(RegExp(r'[^0-9]'), '') ?? 'unknown';
    final safePhone = phoneFolder.isEmpty ? 'unknown' : phoneFolder;
    final objectPath = 'as_calls/$safePhone/${dateStr}_${timestamp}_$fileName';
    return _putPublicObject(filePath: filePath, objectPath: objectPath);
  }

  Future<String> _putPublicObject({
    required String filePath,
    required String objectPath,
  }) async {
    final bucket = dotenv.env['B2_BUCKET']?.trim() ?? 'coadsales2';
    final endpoint = dotenv.env['B2_S3_ENDPOINT']?.trim() ?? '';

    if (!isAllowedPickerPath(filePath, mimeType: lookupMimeType(filePath))) {
      throw ApiException('지원하지 않는 형식입니다. 이미지 또는 PDF만 업로드할 수 있습니다.');
    }

    final minio = _getMinio();
    final fileToUpload = await _compressIfNeeded(filePath);
    final isCompressed = fileToUpload.path != filePath;

    if (!await fileToUpload.exists()) {
      throw ApiException('업로드할 파일을 찾을 수 없습니다.');
    }

    try {
      final contentType =
          lookupMimeType(filePath) ?? 'application/octet-stream';
      await minio
          .putObject(
            bucket,
            objectPath,
            fileToUpload.openRead().map((chunk) => Uint8List.fromList(chunk)),
            size: await fileToUpload.length(),
            metadata: {'Content-Type': contentType},
          )
          .timeout(const Duration(minutes: 5));
      return 'https://$bucket.$endpoint/$objectPath';
    } catch (e) {
      throw ApiException('B2 직접 업로드 실패: $e');
    } finally {
      if (isCompressed && await fileToUpload.exists()) {
        await fileToUpload.delete();
      }
    }
  }
}
