import 'package:coad_customer_calls/core/utils/mail_permissions.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/features/mail/mail_history_page.dart';
import 'package:coad_customer_calls/features/mail/mail_send_page.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MailHubScreen extends ConsumerWidget {
  const MailHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider);
    if (user == null || !canAccessMail(user)) {
      return Scaffold(
        appBar: AppBar(title: const Text('메일 발송')),
        body: const AppEmpty(
          icon: Icons.lock_outline_rounded,
          message: '메일 발송 메뉴 접근 권한이 없습니다.',
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.mailAccent(scheme);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('메일 발송'),
          bottom: TabBar(
            labelColor: accent,
            indicatorColor: accent,
            tabs: const [
              Tab(text: '보내기'),
              Tab(text: '보낸 메일'),
            ],
          ),
        ),
        body: const TabBarView(children: [MailSendPage(), MailHistoryPage()]),
      ),
    );
  }
}
