import 'package:url_launcher/url_launcher.dart';

class LauncherUtils {
  static Future<void> makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber.replaceAll('-', ''),
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  static Future<void> sendSMS(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'sms',
      path: phoneNumber.replaceAll('-', ''),
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  static Future<void> launchKakaoTalk(String phoneNumber) async {
    // KakaoTalk manual chat deep link often uses the phone number
    // However, usually it's better to use the universal link or tell command
    // If we don't have a specific chat ID, we can open KakaoTalk or use search
    // Here we'll try a common approach for phone-based search if applicable
    // Note: Simple 'kakaolink://' or 'kakaotalk://' might need registration
    final Uri launchUri = Uri.parse('https://line.me/R/ti/p/~'); // Placeholder or specific logic
    
    // For now, let's stick to a robust way or informative error
    // In many cases, sales people use 'kakaotalk://send?phone=...' or similar
    // But since KakaoTalk doesn't officially support direct phone search via URL scheme for security
    // We'll just try to open the app or a search intent if possible.
    
    // Fallback: Open phone dialer if others fail, or just show intent.
    final kakaoUri = Uri.parse('kakaotalk://search?q=${phoneNumber.replaceAll('-', '')}');
    if (await canLaunchUrl(kakaoUri)) {
      await launchUrl(kakaoUri);
    }
  }
}
