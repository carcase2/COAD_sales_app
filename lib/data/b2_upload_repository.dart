import 'dart:io';
import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/core/utils/attachment_utils.dart';
import 'package:coad_customer_calls/data/app_dependencies.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:minio/minio.dart';
import 'package:intl/intl.dart';

/// **B2 직접 업로드 기법** — 인트라넷 서버를 거치지 않고 S3 호환 API로 직접 전송.
class B2UploadRepository {
  B2UploadRepository(this._deps);

  final AppDependencies _deps;

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

  /// 업로드 후 공개 [url] 반환.
  Future<String> uploadSalesCallFile({
    required String filePath,
    required String siteName,
  }) async {
    final bucket = dotenv.env['B2_BUCKET']?.trim() ?? 'coadsales2';
    final region = dotenv.env['B2_REGION']?.trim() ?? 'us-east-005';
    final endpoint = dotenv.env['B2_S3_ENDPOINT']?.trim() ?? '';

    if (!isAllowedPickerPath(filePath, mimeType: lookupMimeType(filePath))) {
      throw ApiException('지원하지 않는 형식입니다. 이미지 또는 PDF만 업로드할 수 있습니다.');
    }

    final minio = _getMinio();
    final file = File(filePath);
    if (!await file.exists()) {
      throw ApiException('파일을 찾을 수 없습니다.');
    }

    final now = DateTime.now();
    final dateDir = DateFormat('yyyyMMdd').format(now);
    final fileName = p.basename(filePath);
    final timestamp = now.millisecondsSinceEpoch;
    
    // 파일명 중복 방지를 위해 타임스탬프 접두어 추가
    final objectPath = 'sales_calls/$dateDir/${timestamp}_$fileName';

    try {
      final contentType = lookupMimeType(filePath) ?? 'application/octet-stream';
      
      // 스트림 방식으로 업로드
      await minio.putObject(
        bucket,
        objectPath,
        file.openRead(),
        size: await file.length(),
        metadata: {'Content-Type': contentType},
      ).timeout(const Duration(minutes: 5));

      // B2 S3 버킷 공개 주소 생성
      // https://{bucket}.s3.{region}.backblazeb2.com/{objectPath}
      return 'https://$bucket.$endpoint/$objectPath';
    } catch (e) {
      throw ApiException('B2 직접 업로드 실패: $e');
    }
  }
}
