import 'dart:io';

import 'package:coad_customer_calls/features/business_cards/business_card_crop_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/widgets/image_source_sheet.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 명함 사진을 받아 "명함만 남은" 이미지 경로를 돌려준다. 취소하면 null.
///
/// - 카메라: 기기 문서 스캐너(Android ML Kit · iOS VisionKit)를 띄운다.
///   화면에서 명함 네 모서리를 실시간으로 찾아 자동 촬영·원근 보정까지 하므로
///   세로·가로 명함 모두 네모를 다시 맞출 필요가 없다. 다시 찍기·취소도 스캐너 안에서 끝난다.
/// - 스캐너를 못 쓰는 기기(Play 서비스 없음 등)나 앨범·파일: [pickRaw]로 사진을 고른 뒤
///   자동 테두리 찾기가 들어간 자르기 화면을 띄운다. 그 화면에서 "다시 찍기/선택"을 누르면
///   [pickRaw]를 다시 부른다.
///
/// 중간에 만든 임시 파일(원본 촬영본·스캐너 결과)은 끝나거나 취소될 때 지운다.
Future<String?> captureBusinessCardImage(
  BuildContext context, {
  required SalesCallImageSource source,
  required Future<String?> Function() pickRaw,
}) async {
  if (source == SalesCallImageSource.camera && _scannerSupported) {
    final scanned = await _scanWithDocumentScanner(context);
    if (scanned is _ScanDone) return scanned.path;
    if (scanned is _ScanCancelled) return null;
    // _ScanUnavailable → 아래 수동 흐름으로.
    if (!context.mounted) return null;
  }

  while (true) {
    final raw = await pickRaw();
    if (raw == null || !context.mounted) return null;
    final result = await cropBusinessCardImage(
      context,
      imagePath: raw,
      retakeLabel: source == SalesCallImageSource.camera ? '다시 찍기' : '다시 선택',
    );
    // 자른 결과는 새 파일이라 원본은 필요 없다(앨범 원본은 앱 임시 사본만 지운다).
    _deleteTempQuietly(raw);
    if (!context.mounted) return null;
    switch (result) {
      case CardCropSaved(:final path):
        return path;
      case CardCropRetake():
        continue;
      case CardCropCancelled():
      case null:
        return null;
    }
  }
}

bool get _scannerSupported =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

sealed class _ScanOutcome {}

class _ScanDone extends _ScanOutcome {
  _ScanDone(this.path);
  final String path;
}

class _ScanCancelled extends _ScanOutcome {}

class _ScanUnavailable extends _ScanOutcome {}

Future<_ScanOutcome> _scanWithDocumentScanner(BuildContext context) async {
  try {
    final result = await CunningDocumentScanner.scanDocuments(
      noOfPages: 1,
      scannerSource: ScannerSource.camera,
      // 자르기·회전만 있는 기본 모드: 필터·정리 단계 없이 바로 끝난다.
      androidScannerMode: AndroidScannerMode.base,
    );
    if (result == null || result.images.isEmpty) {
      await _cleanScannerCache();
      return _ScanCancelled();
    }
    // 스캐너 파일은 플러그인 소유(Android에선 자동 삭제 안 됨) → 앱 임시 폴더로 옮긴 뒤 정리.
    final src = File(result.images.first);
    final dir = await getTemporaryDirectory();
    final ext = p.extension(src.path).isEmpty ? '.jpg' : p.extension(src.path);
    final out = p.join(
      dir.path,
      'card_scan_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await src.copy(out);
    await _cleanScannerCache();
    return _ScanDone(out);
  } on CunningDocumentScannerException catch (e) {
    await _cleanScannerCache();
    final denied = (e.code ?? '').toLowerCase().contains('permission');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            denied
                ? '카메라 권한이 필요합니다. 설정에서 허용해 주세요.'
                : '자동 스캐너를 쓸 수 없어 일반 카메라로 촬영합니다.',
          ),
        ),
      );
    }
    return denied ? _ScanCancelled() : _ScanUnavailable();
  } catch (_) {
    await _cleanScannerCache();
    return _ScanUnavailable();
  }
}

Future<void> _cleanScannerCache() async {
  try {
    await CunningDocumentScanner.cleanCache();
  } catch (_) {}
}

/// 앱 임시·캐시 폴더 안의 파일만 지운다(사용자 앨범 원본은 건드리지 않음).
Future<void> _deleteTempQuietly(String path) async {
  try {
    final tmp = (await getTemporaryDirectory()).path;
    final norm = p.normalize(path);
    final inTemp = p.isWithin(tmp, norm) ||
        norm.contains('${p.separator}cache${p.separator}') ||
        norm.contains('${p.separator}Caches${p.separator}') ||
        norm.contains('${p.separator}tmp${p.separator}');
    if (!inTemp) return;
    final f = File(norm);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}
