import 'package:coad_customer_calls/features/quoter/quoter_type_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// 규격 입력 — 시스템 키보드 없이 앱 내 숫자 패드.
/// 가용 높이에 맞춰 압축되며 bottom overflow 없이 맞춘다.
class QuoterSizeKeypad extends StatelessWidget {
  const QuoterSizeKeypad({
    super.key,
    required this.widthMm,
    required this.heightMm,
    required this.editingWidth,
    required this.onSelectWidth,
    required this.onSelectHeight,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    required this.onSetValue,
    required this.onBack,
    required this.onPrimary,
    required this.canCalculate,
    required this.isCalculating,
    this.outOfTable = false,
    this.outOfTableBanner,
  });

  final int widthMm;
  final int heightMm;
  final bool editingWidth;
  final VoidCallback onSelectWidth;
  final VoidCallback onSelectHeight;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  /// 현재 편집 축에 값 통째로 설정 (빠른 규격 칩)
  final ValueChanged<int> onSetValue;
  final VoidCallback onBack;
  final VoidCallback onPrimary;
  final bool canCalculate;
  final bool isCalculating;
  final bool outOfTable;
  final Widget? outOfTableBanner;

  static final _fmt = NumberFormat('#,###');

  /// 현장 자주 쓰는 mm 규격
  static const quickSizes = [1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = quoterStepAccent(2);
    final current = editingWidth ? widthMm : heightMm;

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        // 좁은 화면: 축 카드·칩·버튼 축소
        final compact = h < 460;
        final tight = h < 380;
        final axisH = tight ? 56.0 : (compact ? 64.0 : 72.0);
        final chipH = tight ? 28.0 : 32.0;
        final actionH = tight ? 42.0 : 48.0;
        final gap = tight ? 4.0 : 6.0;
        final showHint = !tight;
        final showBanner = outOfTable && outOfTableBanner != null && !tight;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 폭 · 높이
            SizedBox(
              height: axisH,
              child: Row(
                children: [
                  Expanded(
                    child: _AxisCard(
                      label: '폭 W',
                      valueMm: widthMm,
                      selected: editingWidth,
                      accent: accent,
                      scheme: scheme,
                      compact: compact,
                      onTap: onSelectWidth,
                    ),
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    child: _AxisCard(
                      label: '높이 H',
                      valueMm: heightMm,
                      selected: !editingWidth,
                      accent: accent,
                      scheme: scheme,
                      compact: compact,
                      onTap: onSelectHeight,
                    ),
                  ),
                ],
              ),
            ),
            if (showBanner) ...[
              SizedBox(height: gap),
              outOfTableBanner!,
            ],
            if (showHint) ...[
              SizedBox(height: gap),
              Text(
                editingWidth
                    ? '폭 입력 → 「다음」→ 높이'
                    : (canCalculate
                        ? '높이 확인 후 「견적 산출」'
                        : '높이를 입력하세요'),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            SizedBox(height: gap),
            // 빠른 규격
            SizedBox(
              height: chipH,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: quickSizes.length,
                separatorBuilder: (_, _) => SizedBox(width: gap),
                itemBuilder: (context, i) {
                  final size = quickSizes[i];
                  final selected = current == size;
                  return Align(
                    alignment: Alignment.center,
                    child: Material(
                      color: selected
                          ? accent
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(chipH / 2),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onSetValue(size);
                        },
                        borderRadius: BorderRadius.circular(chipH / 2),
                        child: Container(
                          height: chipH,
                          alignment: Alignment.center,
                          padding: EdgeInsets.symmetric(
                            horizontal: tight ? 10 : 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(chipH / 2),
                            border: Border.all(
                              color: selected
                                  ? accent
                                  : scheme.outlineVariant
                                      .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            _fmt.format(size),
                            style: TextStyle(
                              fontSize: tight ? 12 : 13,
                              fontWeight: FontWeight.w800,
                              height: 1,
                              color: selected
                                  ? scheme.onPrimary
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: gap),
            // 숫자 패드 — 남는 공간 전부 (최소 높이 강제 없음)
            Expanded(
              child: _NumberPad(
                accent: accent,
                scheme: scheme,
                tight: tight,
                onDigit: onDigit,
                onBackspace: onBackspace,
                onClear: onClear,
              ),
            ),
            SizedBox(height: gap),
            // 하단 액션
            SizedBox(
              height: actionH,
              child: Row(
                children: [
                  SizedBox(
                    width: actionH,
                    height: actionH,
                    child: IconButton(
                      tooltip: '종류로',
                      onPressed: onBack,
                      style: IconButton.styleFrom(
                        minimumSize: Size(actionH, actionH),
                        maximumSize: Size(actionH, actionH),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        size: tight ? 20 : 22,
                      ),
                    ),
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    child: FilledButton(
                      onPressed: !_canPrimary
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              onPrimary();
                            },
                      style: FilledButton.styleFrom(
                        minimumSize: Size.fromHeight(actionH),
                        maximumSize: Size.fromHeight(actionH),
                        backgroundColor: accent,
                        disabledBackgroundColor:
                            scheme.onSurface.withValues(alpha: 0.12),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: isCalculating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _primaryLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: tight ? 14 : 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  bool get _canPrimary {
    if (isCalculating) return false;
    if (editingWidth) return widthMm > 0;
    return canCalculate;
  }

  String get _primaryLabel {
    if (editingWidth) {
      return widthMm > 0 ? '다음 (높이)' : '폭 입력';
    }
    if (canCalculate) return '견적 산출';
    return '높이 입력';
  }

  static String formatMm(int mm) => mm > 0 ? _fmt.format(mm) : '—';
}

class _AxisCard extends StatelessWidget {
  const _AxisCard({
    required this.label,
    required this.valueMm,
    required this.selected,
    required this.accent,
    required this.scheme,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final int valueMm;
  final bool selected;
  final Color accent;
  final ColorScheme scheme;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? accent.withValues(alpha: 0.16)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: EdgeInsets.symmetric(
            horizontal: 6,
            vertical: compact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? accent
                  : scheme.outlineVariant.withValues(alpha: 0.4),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 10.5 : 11.5,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  color: selected ? accent : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 1),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      QuoterSizeKeypad.formatMm(valueMm),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: compact ? 24 : 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        height: 1,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                'mm',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberPad extends StatelessWidget {
  const _NumberPad({
    required this.accent,
    required this.scheme,
    required this.tight,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
  });

  final Color accent;
  final ColorScheme scheme;
  final bool tight;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final keys = <List<String>>[
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', '⌫'],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // 남는 높이를 4등분 — 최소 높이 강제 없음 (overflow 방지)
        final gap = tight ? 4.0 : 5.0;
        final avail = constraints.maxHeight;
        if (avail <= 0) return const SizedBox.shrink();

        final rowH = ((avail - gap * 3) / 4).clamp(0.0, 72.0);
        // 행 합이 가용 높이를 넘지 않도록 보정
        final total = rowH * 4 + gap * 3;
        final scale = total > avail && total > 0 ? avail / total : 1.0;
        final h = rowH * scale;
        final g = gap * scale;

        return Column(
          children: [
            for (var r = 0; r < keys.length; r++) ...[
              if (r > 0) SizedBox(height: g),
              SizedBox(
                height: h,
                child: Row(
                  children: [
                    for (var c = 0; c < 3; c++) ...[
                      if (c > 0) SizedBox(width: g),
                      Expanded(
                        child: _PadKey(
                          label: keys[r][c],
                          accent: accent,
                          scheme: scheme,
                          fontSize: h < 36 ? 16.0 : (tight ? 18.0 : 20.0),
                          onTap: () {
                            final k = keys[r][c];
                            HapticFeedback.selectionClick();
                            if (k == 'C') {
                              onClear();
                            } else if (k == '⌫') {
                              onBackspace();
                            } else {
                              onDigit(k);
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({
    required this.label,
    required this.accent,
    required this.scheme,
    required this.fontSize,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final ColorScheme scheme;
  final double fontSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isAction = label == 'C' || label == '⌫';
    return Material(
      color: isAction
          ? scheme.surfaceContainerHighest
          : scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: label == '⌫' ? fontSize - 1 : fontSize,
                fontWeight: FontWeight.w900,
                height: 1,
                color: isAction ? scheme.onSurfaceVariant : scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
