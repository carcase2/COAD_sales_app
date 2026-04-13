import 'package:coad_customer_calls/core/utils/attachment_utils.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// `sales_calls.images` URL 목록 — 이미지 미리보기, PDF는 외부 앱으로 열기
class SalesCallAttachmentsStrip extends StatelessWidget {
  const SalesCallAttachmentsStrip({
    super.key,
    required this.urls,
    this.editable = false,
    this.onRemoveAt,
    this.onAdd,
    this.uploadBusy = false,
    this.progressLabel,
  });

  final List<String> urls;
  final bool editable;
  final void Function(int index)? onRemoveAt;
  final VoidCallback? onAdd;
  final bool uploadBusy;
  final String? progressLabel;

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

  void _previewImage(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => Scaffold(
          appBar: AppBar(title: const Text('이미지')),
          body: Center(
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
          ),
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
                              _openUrl(context, u);
                            } else if (kind == AttachmentKind.image) {
                              _previewImage(context, u);
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
