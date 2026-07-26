import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class LauncherUtils {
  static String _digitsOnly(String phoneNumber) =>
      phoneNumber.replaceAll(RegExp(r'\D'), '');

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
