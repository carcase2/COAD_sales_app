import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class LauncherUtils {
  static String _digitsOnly(String phoneNumber) =>
      phoneNumber.replaceAll(RegExp(r'\D'), '');

  static Future<void> copyPhone(
    BuildContext context,
    String phoneNumber, {
    String? emptyMessage,
  }) async {
    final raw = phoneNumber.trim();
    if (raw.isEmpty || _digitsOnly(raw).isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(emptyMessage ?? '복사할 연락처가 없습니다.')),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: raw));
    HapticFeedback.selectionClick();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$raw 복사했습니다.')),
    );
  }

  static Future<String?> clipboardPhoneDigits() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final digits = _digitsOnly(data?.text ?? '');
    if (digits.length < 8) return null;
    return digits;
  }

  static Future<void> makePhoneCall(String phoneNumber) async {
    final digits = _digitsOnly(phoneNumber);
    if (digits.isEmpty) return;
    HapticFeedback.mediumImpact();
    final Uri launchUri = Uri(scheme: 'tel', path: digits);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  static Future<void> sendSMS(String phoneNumber) async {
    final digits = _digitsOnly(phoneNumber);
    if (digits.isEmpty) return;
    HapticFeedback.lightImpact();
    final Uri launchUri = Uri(scheme: 'sms', path: digits);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  static Future<void> launchKakaoTalk(String phoneNumber) async {
    final digits = _digitsOnly(phoneNumber);
    if (digits.isEmpty) return;
    final kakaoUri = Uri.parse('kakaotalk://search?q=$digits');
    if (await canLaunchUrl(kakaoUri)) {
      await launchUrl(kakaoUri);
    }
  }
}
