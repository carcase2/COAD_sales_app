import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// 입력 중 천 단위 콤마를 유지하는 숫자 포매터.
/// 커서 위치는 콤마를 제외한 자릿수를 기준으로 복원한다.
class ThousandsFormatter extends TextInputFormatter {
  const ThousandsFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final digitsOnly = newValue.text.replaceAll(',', '');
    final intValue = int.tryParse(digitsOnly);
    if (intValue == null) return oldValue;
    final formatted = NumberFormat('#,###').format(intValue);

    final selectionIndex =
        newValue.selection.end.clamp(0, newValue.text.length);
    final digitsBeforeCaret = newValue.text
        .substring(0, selectionIndex)
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;

    var caret = formatted.length;
    if (digitsBeforeCaret == 0) {
      caret = 0;
    } else {
      var digitCount = 0;
      for (var i = 0; i < formatted.length; i++) {
        if (formatted.codeUnitAt(i) == 0x2C) continue; // ','
        digitCount++;
        if (digitCount >= digitsBeforeCaret) {
          caret = i + 1;
          break;
        }
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: caret),
    );
  }
}
