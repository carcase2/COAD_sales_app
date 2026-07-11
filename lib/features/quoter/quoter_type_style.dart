import 'package:coad_customer_calls/models/shutter_models.dart';
import 'package:flutter/material.dart';

/// 견적기 마법사 단계별 악센트 (1=종류, 2=규격, 3=비용, 4=결과)
const kQuoterStepAccents = <Color>[
  Color(0xFF1565C0),
  Color(0xFF00897B),
  Color(0xFFE65100),
  Color(0xFF6A1B9A),
];

Color quoterStepAccent(int step) => kQuoterStepAccents[step - 1];

/// 셔터 종류 표시용 라벨·아이콘·색.
class QuoterTypeStyle {
  QuoterTypeStyle._();

  static String label(ShutterType type) {
    switch (type) {
      case ShutterType.doubleExtrusion:
        return '이중압출';
      case ShutterType.doubleExtrusionInsulated:
        return '이중압출단열';
      case ShutterType.windproof:
        return '내풍압';
      case ShutterType.windproofInsulated:
        return '내풍압단열';
      case ShutterType.fireSteel:
        return '철제방화';
      case ShutterType.fireScreen:
        return '스크린방화';
    }
  }

  static IconData icon(ShutterType type) {
    switch (type) {
      case ShutterType.doubleExtrusion:
        return Icons.layers_rounded;
      case ShutterType.doubleExtrusionInsulated:
        return Icons.layers_clear_rounded;
      case ShutterType.windproof:
        return Icons.air_rounded;
      case ShutterType.windproofInsulated:
        return Icons.shield_rounded;
      case ShutterType.fireSteel:
        return Icons.local_fire_department_rounded;
      case ShutterType.fireScreen:
        return Icons.fire_extinguisher_rounded;
    }
  }

  static Color color(ShutterType type) {
    switch (type) {
      case ShutterType.doubleExtrusion:
        return const Color(0xFF1565C0);
      case ShutterType.doubleExtrusionInsulated:
        return const Color(0xFF0277BD);
      case ShutterType.windproof:
        return const Color(0xFF283593);
      case ShutterType.windproofInsulated:
        return const Color(0xFF4527A0);
      case ShutterType.fireSteel:
        return const Color(0xFF37474F);
      case ShutterType.fireScreen:
        return const Color(0xFFE65100);
    }
  }
}
