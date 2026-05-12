import 'package:coad_customer_calls/features/quoter/estimate_writer_screen.dart';
import 'package:coad_customer_calls/features/quoter/quoter_screen.dart';
import 'package:flutter/material.dart';

class QuoterHubScreen extends StatelessWidget {
  const QuoterHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: '셔터 견적기 (테스트중)'),
              Tab(text: '견적서 작성'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                QuoterScreen(showQuickActions: false),
                EstimateWriterScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
