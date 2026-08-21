import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/core/widgets/search_highlight_text.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_widgets.dart';
import 'package:flutter/material.dart';

class _FaqItem {
  const _FaqItem({
    required this.title,
    required this.body,
    required this.hasImage,
  });

  final String title;
  final String body;
  final bool hasImage;
}

const _kSampleFaqs = <_FaqItem>[
  _FaqItem(
    title: '모터 소음이 날 때',
    body: '베어링·체인 텐션을 먼저 확인합니다. 현장 사진 두 장 이상 첨부.',
    hasImage: true,
  ),
  _FaqItem(
    title: '리모컨이 안 될 때',
    body: '수신기 전원과 주파수 점퍼를 확인한 뒤 교체 견적.',
    hasImage: false,
  ),
  _FaqItem(
    title: '유상/무상 판단',
    body: '설치 1년 이내 무상. 이후 유상. 소모품은 별도.',
    hasImage: false,
  ),
];

class CustomerSupportFaqScreen extends StatefulWidget {
  const CustomerSupportFaqScreen({super.key});

  @override
  State<CustomerSupportFaqScreen> createState() =>
      _CustomerSupportFaqScreenState();
}

class _CustomerSupportFaqScreenState extends State<CustomerSupportFaqScreen> {
  final _queryCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  List<_FaqItem> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _kSampleFaqs;
    return _kSampleFaqs
        .where(
          (f) =>
              f.title.toLowerCase().contains(q) ||
              f.body.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('교육 FAQ'),
        actions: const [SupportExcelButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCompose(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('작성'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: SearchBar(
              controller: _queryCtrl,
              hintText: 'FAQ 검색',
              leading: const Icon(Icons.search_rounded, size: 20),
              onChanged: (v) => setState(() => _query = v),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 10),
              ),
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(
                scheme.surfaceContainerHighest.withValues(alpha: 0.55),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SupportComingSoonBanner(
              message: '검색·작성·이미지 첨부 자리입니다. 업로드는 다음 작업입니다.',
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const AppEmpty(message: '검색 결과가 없습니다.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final faq = items[i];
                      return ListTile(
                        tileColor: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.42,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        leading: Icon(
                          faq.hasImage
                              ? Icons.image_outlined
                              : Icons.article_outlined,
                        ),
                        title: SearchHighlightText(
                          text: faq.title,
                          query: _query,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: SearchHighlightText(
                          text: faq.body,
                          query: _query,
                          maxLines: 2,
                        ),
                        onTap: () =>
                            showSupportSkeletonSnack(context, 'FAQ 상세'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openCompose(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'FAQ 작성',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              const TextField(decoration: InputDecoration(labelText: '제목')),
              const SizedBox(height: 8),
              const TextField(
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(labelText: '내용'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => showSupportSkeletonSnack(ctx, '이미지 첨부'),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('이미지 첨부'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  showSupportSkeletonSnack(context, 'FAQ 저장');
                },
                child: const Text('저장'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
