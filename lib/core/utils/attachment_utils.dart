import 'package:mime/mime.dart';

/// 웹 고객전화와 동일한 첨부(이미지 / PDF) 판별
enum AttachmentKind { image, pdf, unsupported }

AttachmentKind classifyAttachmentUrl(String url) {
  final u = url.split('?').first.toLowerCase();
  if (u.endsWith('.pdf')) return AttachmentKind.pdf;
  const img = [
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.bmp',
    '.webp',
    '.svg',
    '.heic',
    '.heif',
    '.tif',
    '.tiff',
  ];
  for (final ext in img) {
    if (u.endsWith(ext)) return AttachmentKind.image;
  }
  return AttachmentKind.unsupported;
}

bool isAllowedPickerPath(String path, {String? mimeType}) {
  final m = mimeType?.toLowerCase() ?? lookupMimeType(path)?.toLowerCase();
  if (m != null) {
    if (m == 'application/pdf') return true;
    if (m.startsWith('image/')) return true;
  }
  final lower = path.toLowerCase();
  if (lower.endsWith('.pdf')) return true;
  const img = [
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.bmp',
    '.webp',
    '.svg',
    '.heic',
    '.heif',
    '.tif',
    '.tiff',
  ];
  return img.any(lower.endsWith);
}

bool isImageFile(String path) {
  return classifyAttachmentUrl(path) == AttachmentKind.image;
}
