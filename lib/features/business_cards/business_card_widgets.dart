import 'dart:async';

import 'package:coad_customer_calls/core/utils/launcher_utils.dart';
import 'package:coad_customer_calls/core/widgets/cached_app_image.dart';
import 'package:coad_customer_calls/data/business_card_repository.dart';
import 'package:coad_customer_calls/data/business_card_vcard.dart';
import 'package:coad_customer_calls/models/business_card.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BusinessCardAvatar extends StatelessWidget {
  const BusinessCardAvatar({super.key, required this.card, this.size = 48});

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
      backgroundColor:
          (private ? scheme.errorContainer : scheme.secondaryContainer)
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

/// 목록에서 길게 눌렀을 때 — 번호별 전화·문자·복사, 메일 복사, 연락처 저장·공유.
Future<void> showBusinessCardQuickActions(
  BuildContext context,
  BusinessCard card,
) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      final phones = businessCardPhoneOptions(card);
      void close() => Navigator.of(sheetContext).pop();
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                card.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ),
            for (final p in phones)
              ListTile(
                leading: Icon(
                  p.label == '팩스' ? Icons.fax_outlined : Icons.call_rounded,
                  color: scheme.primary,
                ),
                title: Text(p.phone),
                subtitle: Text(p.label),
                // 팩스는 걸지 않고 복사만 한다.
                onTap: p.label == '팩스'
                    ? null
                    : () {
                        close();
                        unawaited(LauncherUtils.makePhoneCall(p.phone));
                      },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (p.label == '휴대폰')
                      IconButton(
                        tooltip: '문자',
                        icon: const Icon(Icons.sms_outlined),
                        onPressed: () {
                          close();
                          unawaited(LauncherUtils.sendSMS(p.phone));
                        },
                      ),
                    IconButton(
                      tooltip: '번호 복사',
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () {
                        close();
                        unawaited(LauncherUtils.copyPhone(context, p.phone));
                      },
                    ),
                  ],
                ),
              ),
            if (card.email.trim().isNotEmpty)
              ListTile(
                leading: Icon(
                  Icons.mail_outline_rounded,
                  color: scheme.primary,
                ),
                title: Text(card.email),
                subtitle: const Text('메일 주소 복사'),
                onTap: () {
                  close();
                  unawaited(
                    Clipboard.setData(ClipboardData(text: card.email.trim())),
                  );
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(content: Text('${card.email.trim()} 복사했습니다.')),
                  );
                },
              ),
            ListTile(
              leading: Icon(
                Icons.contact_phone_outlined,
                color: scheme.primary,
              ),
              title: const Text('연락처에 저장 · 공유'),
              onTap: () {
                close();
                unawaited(shareBusinessCardVCard(context, card));
              },
            ),
          ],
        ),
      );
    },
  );
}
