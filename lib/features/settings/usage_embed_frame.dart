import 'package:flutter/material.dart';

/// 사용량 화면을 단독으로 열거나, 앱 사용량 탭 안에 넣을 때 같이 쓴다.
class UsageEmbedFrame extends StatelessWidget {
  const UsageEmbedFrame({
    super.key,
    required this.embedded,
    required this.title,
    required this.body,
    this.actions = const [],
  });

  final bool embedded;
  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (!embedded) {
      return Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: body,
      );
    }
    if (actions.isEmpty) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Row(mainAxisSize: MainAxisSize.min, children: actions),
        ),
        Expanded(child: body),
      ],
    );
  }
}
