import 'dart:typed_data';
import 'package:coad_customer_calls/core/utils/attachment_utils.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// `sales_calls.images` URL 목록 — 이미지 미리보기, PDF는 외부 앱으로 열기
class SalesCallAttachmentsStrip extends StatelessWidget {
  const SalesCallAttachmentsStrip({
    super.key,
    required this.urls,
    this.saveNamePrefix,
    this.editable = false,
    this.onRemoveAt,
    this.onAdd,
    this.uploadBusy = false,
    this.progressLabel,
  });

  final List<String> urls;
  final String? saveNamePrefix;
  final bool editable;
  final void Function(int index)? onRemoveAt;
  final VoidCallback? onAdd;
  final bool uploadBusy;
  final String? progressLabel;

  Future<Uint8List?> _downloadBytes(BuildContext context, String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return null;
      final res = await http.get(uri);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return res.bodyBytes;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('파일 다운로드에 실패했습니다.')),
        );
      }
      return null;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('파일 다운로드 중 오류가 발생했습니다.')),
        );
      }
      return null;
    }
  }

  String _extOfUrl(String url) {
    final uri = Uri.tryParse(url);
    final p = uri?.path.toLowerCase() ?? url.toLowerCase();
    final dot = p.lastIndexOf('.');
    if (dot < 0 || dot + 1 >= p.length) return 'bin';
    final ext = p.substring(dot + 1);
    if (ext.length > 8) return 'bin';
    return ext;
  }

  String _sanitizeName(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9a-zA-Z가-힣_-]'), '_');
    final compact = cleaned.replaceAll(RegExp(r'_+'), '_').trim();
    if (compact.isEmpty) return 'attachment';
    return compact;
  }

  String _baseNameFor({
    required AttachmentKind kind,
    required int sequence,
  }) {
    final prefix = _sanitizeName((saveNamePrefix ?? 'coad').trim());
    if (kind == AttachmentKind.image) return '${prefix}_사진$sequence';
    if (kind == AttachmentKind.pdf) return '${prefix}_문서$sequence';
    return '${prefix}_파일$sequence';
  }

  MimeType _mimeTypeFor(String ext, AttachmentKind kind) {
    if (kind == AttachmentKind.pdf || ext == 'pdf') return MimeType.pdf;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MimeType.jpeg;
      case 'png':
        return MimeType.png;
      case 'gif':
        return MimeType.gif;
      case 'webp':
        return MimeType.webp;
      default:
        return MimeType.other;
    }
  }

  Future<bool> _saveOne(
    BuildContext context,
    String url, {
    required int sequence,
    required AttachmentKind kind,
  }) async {
    final bytes = await _downloadBytes(context, url);
    if (bytes == null) return false;
    final ext = _extOfUrl(url);
    final baseName = _baseNameFor(
      kind: kind == AttachmentKind.unsupported && ext == 'pdf' ? AttachmentKind.pdf : kind,
      sequence: sequence,
    );
    try {
      await FileSaver.instance.saveFile(
        name: baseName,
        bytes: bytes,
        fileExtension: ext,
        mimeType: _mimeTypeFor(ext, kind),
      );
      return true;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$baseName 저장에 실패했습니다.')),
        );
      }
      return false;
    }
  }

  Future<void> _openPdfMenu(BuildContext context, String url, int sequence) async {
    final kind = classifyAttachmentUrl(url);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('열기'),
              onTap: () {
                Navigator.of(ctx).pop();
                _openUrl(context, url);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('저장'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final done = await _saveOne(
                  context,
                  url,
                  sequence: sequence,
                  kind: kind,
                );
                if (!context.mounted || !done) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('파일을 저장했습니다.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('주소 형식이 올바르지 않습니다.')),
      );
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('파일을 열 수 없습니다.')),
      );
    }
  }

  void _previewImage(BuildContext context, List<String> imageUrls, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => _ImagePreviewPagerScreen(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
          saveCurrent: (index) => _saveOne(
            ctx,
            imageUrls[index],
            sequence: index + 1,
            kind: AttachmentKind.image,
          ),
          saveAll: () async {
            var ok = 0;
            for (var i = 0; i < imageUrls.length; i++) {
              if (await _saveOne(
                ctx,
                imageUrls[i],
                sequence: i + 1,
                kind: AttachmentKind.image,
              )) {
                ok += 1;
              }
            }
            return ok;
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.attach_file, size: 20, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '첨부 (${urls.length})',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (onAdd != null) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: uploadBusy ? null : onAdd,
                icon: uploadBusy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
                      )
                    : const Icon(Icons.add_photo_alternate_outlined, size: 20),
                label: Text(uploadBusy 
                    ? (progressLabel ?? '업로드 중…') 
                    : '추가'),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ],
        ),
        if (urls.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              editable ? '사진 또는 PDF를 추가할 수 있습니다.' : '첨부 파일이 없습니다.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(urls.length, (i) {
                final u = urls[i];
                final kind = classifyAttachmentUrl(u);
                return Material(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    width: kind == AttachmentKind.image ? 108 : 140,
                    height: 108,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        InkWell(
                          onTap: () {
                            if (kind == AttachmentKind.pdf) {
                              _openPdfMenu(context, u, i + 1);
                            } else if (kind == AttachmentKind.image) {
                              final imageUrls = urls
                                  .where((x) => classifyAttachmentUrl(x) == AttachmentKind.image)
                                  .toList(growable: false);
                              final imageIndex = imageUrls.indexOf(u);
                              _previewImage(
                                context,
                                imageUrls,
                                imageIndex < 0 ? 0 : imageIndex,
                              );
                            } else {
                              _openUrl(context, u);
                            }
                          },
                          child: kind == AttachmentKind.image
                              ? Image.network(
                                  u,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Center(
                                    child: Icon(Icons.broken_image_outlined, color: scheme.outline),
                                  ),
                                )
                              : Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          kind == AttachmentKind.pdf
                                              ? Icons.picture_as_pdf
                                              : Icons.insert_drive_file_outlined,
                                          size: 36,
                                          color: scheme.primary,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          kind == AttachmentKind.pdf ? 'PDF' : '파일',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                          textAlign: TextAlign.center,
                                        ),
                                        const Text('탭하여 열기', style: TextStyle(fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                        if (editable && onRemoveAt != null)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Material(
                              color: scheme.error.withValues(alpha: 0.92),
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('파일 삭제'),
                                      content: const Text('첨부된 파일을 삭제하시겠습니까?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('취소'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('삭제', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) onRemoveAt?.call(i);
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _ImagePreviewPagerScreen extends StatefulWidget {
  const _ImagePreviewPagerScreen({
    required this.imageUrls,
    required this.initialIndex,
    required this.saveCurrent,
    required this.saveAll,
  });

  final List<String> imageUrls;
  final int initialIndex;
  final Future<bool> Function(int index) saveCurrent;
  final Future<int> Function() saveAll;

  @override
  State<_ImagePreviewPagerScreen> createState() => _ImagePreviewPagerScreenState();
}

class _ImagePreviewPagerScreenState extends State<_ImagePreviewPagerScreen> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _controller = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goPrev() {
    if (_currentIndex <= 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _goNext() {
    if (_currentIndex >= widget.imageUrls.length - 1) return;
    _controller.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = widget.imageUrls.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('이미지'),
        actions: [
          IconButton(
            tooltip: '저장',
            onPressed: () async {
              await showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.download_for_offline_outlined),
                        title: const Text('한 장 저장'),
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          final done = await widget.saveCurrent(_currentIndex);
                          if (!mounted || !done) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('현재 이미지를 저장했습니다.')),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.download_done_rounded),
                        title: const Text('모두 저장'),
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          final ok = await widget.saveAll();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('저장 완료: $ok/${widget.imageUrls.length}개')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
            icon: const Icon(Icons.download_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Text(
                '${_currentIndex + 1}/$total',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: total,
            onPageChanged: (idx) => setState(() => _currentIndex = idx),
            itemBuilder: (context, index) {
              final url = widget.imageUrls[index];
              return Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (c, child, prog) {
                      if (prog == null) return child;
                      return const Padding(
                        padding: EdgeInsets.all(48),
                        child: CircularProgressIndicator(),
                      );
                    },
                    errorBuilder: (_, _, _) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('이미지를 불러올 수 없습니다.\n네트워크를 확인해 주세요.'),
                    ),
                  ),
                ),
              );
            },
          ),
          if (total > 1)
            Positioned(
              left: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton.filledTonal(
                  onPressed: _currentIndex > 0 ? _goPrev : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.86),
                  ),
                ),
              ),
            ),
          if (total > 1)
            Positioned(
              right: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton.filledTonal(
                  onPressed: _currentIndex < total - 1 ? _goNext : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.86),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
