import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/data/size_quote_repository.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 지사별 견적서 주소와 메일을 고친다.
class SizeQuoteOfficeScreen extends ConsumerStatefulWidget {
  const SizeQuoteOfficeScreen({super.key});

  @override
  ConsumerState<SizeQuoteOfficeScreen> createState() =>
      _SizeQuoteOfficeScreenState();
}

class _SizeQuoteOfficeScreenState extends ConsumerState<SizeQuoteOfficeScreen> {
  List<QuoteBranchContact> _rows = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ref
          .read(sizeQuoteRepositoryProvider)
          .loadQuoteBranchContacts();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = koreanErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _edit(QuoteBranchContact row) async {
    final addressCtrl = TextEditingController(text: row.address);
    final emailCtrl = TextEditingController(text: row.email);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(row.name, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(
                  labelText: '주소',
                  filled: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  filled: true,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('저장'),
              ),
            ],
          ),
        );
      },
    );
    final address = addressCtrl.text;
    final email = emailCtrl.text;
    addressCtrl.dispose();
    emailCtrl.dispose();
    if (saved != true || !mounted) return;
    try {
      await ref.read(sizeQuoteRepositoryProvider).saveQuoteBranchContact(
            id: row.id,
            address: address,
            email: email,
          );
      if (!mounted) return;
      setState(() {
        _rows = [
          for (final item in _rows)
            if (item.id == row.id)
              QuoteBranchContact(
                id: item.id,
                name: item.name,
                shortName: item.shortName,
                address: address.trim(),
                email: email.trim(),
              )
            else
              item,
        ];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(koreanErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('지사 주소 · 메일')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    Text(
                      '로그인한 사람의 지사 주소와 메일이 견적서에 찍힙니다.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    for (final row in _rows)
                      Card(
                        child: ListTile(
                          title: Text(row.name),
                          subtitle: Text(
                            [
                              if (row.address.trim().isEmpty)
                                '주소 없음'
                              else
                                row.address.trim(),
                              if (row.email.trim().isEmpty)
                                '메일 없음'
                              else
                                row.email.trim(),
                            ].join('\n'),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.edit_outlined),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _edit(row);
                          },
                        ),
                      ),
                  ],
                ),
    );
  }
}
