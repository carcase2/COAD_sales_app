import 'dart:io';

import 'package:coad_customer_calls/core/widgets/cached_app_image.dart';
import 'package:coad_customer_calls/features/customer_support/support_unit_price.dart';
import 'package:flutter/material.dart';

class SupportUnitPricePhoto extends StatelessWidget {
  const SupportUnitPricePhoto({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 10,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trimmed = url.trim();
    // 표시 크기(화면 배율 3배까지)만큼만 디코드 — 작은 칸에 원본을 통째로 풀지 않는다.
    final w = width;
    final cacheWidth = (w != null && w.isFinite && w > 0)
        ? (w * 3).round()
        : 1600;
    Widget child;
    if (trimmed.isEmpty) {
      child = ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Icon(Icons.image_outlined, color: scheme.outline),
      );
    } else if (trimmed.startsWith('assets/')) {
      child = Image.asset(trimmed, fit: fit, width: width, height: height);
    } else if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://')) {
      child = CachedAppImage(
        url: trimmed,
        fit: fit,
        width: width,
        height: height,
        memCacheWidth: cacheWidth,
      );
    } else {
      child = Image.file(
        File(trimmed),
        fit: fit,
        width: width,
        height: height,
        cacheWidth: cacheWidth,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: width, height: height, child: child),
    );
  }
}

Future<void> showSupportUnitPricePhotos(
  BuildContext context,
  SupportUnitPriceItem item,
) {
  final urls = item.photoUrls;
  if (urls.isEmpty) return Future.value();
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 520,
          height: MediaQuery.sizeOf(ctx).height * 0.72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  children: [
                    for (final url in urls)
                      InteractiveViewer(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                          child: SupportUnitPricePhoto(
                            url: url,
                            fit: BoxFit.contain,
                            radius: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (urls.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '사진 ${urls.length}장 · 옆으로 밀면 도해',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
