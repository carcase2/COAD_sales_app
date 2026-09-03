import 'package:coad_customer_calls/features/customer_support/customer_support_flow.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_writer_screen.dart';
import 'package:flutter/material.dart';

class CustomerSupportQuoteScreen extends StatelessWidget {
  const CustomerSupportQuoteScreen({super.key, this.site, this.callLogId});

  final SupportSiteSample? site;
  final String? callLogId;

  @override
  Widget build(BuildContext context) {
    return SupportQuoteWriterScreen(
      site: site,
      callLogId: callLogId,
      startNew: true,
    );
  }
}
