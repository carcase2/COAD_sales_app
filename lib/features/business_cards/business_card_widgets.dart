import 'package:coad_customer_calls/core/widgets/cached_app_image.dart';
import 'package:coad_customer_calls/models/business_card.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';

class BusinessCardAvatar extends StatelessWidget {
  const BusinessCardAvatar({
    super.key,
    required this.card,
    this.size = 48,
  });

  final BusinessCard card;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (card.imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: CachedAppImage(
          url: card.imageUrl,
          width: size,
          height: size,
          memCacheWidth: (size * 3).round(),
          memCacheHeight: (size * 3).round(),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Text(
        card.initials,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: size * 0.32,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class BusinessCardVisibilityChip extends StatelessWidget {
  const BusinessCardVisibilityChip({super.key, required this.visibility});

  final BusinessCardVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final private = visibility == BusinessCardVisibility.private;
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(
        private ? Icons.lock_outline_rounded : Icons.groups_outlined,
        size: 16,
        color: private ? scheme.error : AppTokens.info(scheme),
      ),
      label: Text(visibility.label),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      padding: EdgeInsets.zero,
      side: BorderSide.none,
      backgroundColor: (private ? scheme.errorContainer : scheme.secondaryContainer)
          .withValues(alpha: 0.7),
    );
  }
}

class BusinessCardBlacklistChip extends StatelessWidget {
  const BusinessCardBlacklistChip({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(Icons.block_rounded, size: 16, color: scheme.error),
      label: const Text('블랙리스트'),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 12,
        color: scheme.error,
      ),
      padding: EdgeInsets.zero,
      side: BorderSide.none,
      backgroundColor: scheme.errorContainer.withValues(alpha: 0.85),
    );
  }
}

Future<void> openBusinessCardImageViewer(
  BuildContext context, {
  required String url,
  String title = '명함 사진',
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _BusinessCardImageViewer(url: url, title: title),
    ),
  );
}

class _BusinessCardImageViewer extends StatelessWidget {
  const _BusinessCardImageViewer({required this.url, required this.title});

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(48),
            minScale: 0.5,
            maxScale: 6,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Center(
                child: CachedAppImage(
                  url: url,
                  fit: BoxFit.contain,
                  placeholder: const Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      '이미지를 불러올 수 없습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

InputDecoration businessCardInputDecoration(BuildContext context, String hint) {
  final scheme = Theme.of(context).colorScheme;
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      borderSide: BorderSide.none,
    ),
  );
}
