import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 네트워크 이미지 디스크 캐시 + 썸네일 메모리 절약.
class CachedAppImage extends StatelessWidget {
  const CachedAppImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.memCacheWidth,
    this.memCacheHeight,
    this.httpHeaders,
    this.placeholder,
    this.errorWidget,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final int? memCacheHeight;
  /// Edge Function 등 인증이 필요한 미디어용 (apikey / Authorization).
  final Map<String, String>? httpHeaders;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      httpHeaders: httpHeaders,
      placeholder: (_, _) =>
          placeholder ??
          const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      errorWidget: (_, _, _) =>
          errorWidget ??
          const Center(child: Icon(Icons.broken_image_outlined)),
    );
  }
}
