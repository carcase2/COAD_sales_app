import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/data/size_quote_repository.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_spec_note.dart';
import 'package:coad_customer_calls/features/unit_price/standard_unit_price_models.dart';
import 'package:coad_customer_calls/features/unit_price/standard_unit_price_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 공통 노트와 모델별 노트를 DB에서 고친다.
class SizeQuoteNoteScreen extends ConsumerStatefulWidget {
  const SizeQuoteNoteScreen({super.key});

  @override
  ConsumerState<SizeQuoteNoteScreen> createState() =>
      _SizeQuoteNoteScreenState();
}

class _NoteTarget {
  const _NoteTarget({
    required this.categoryName,
    required this.modelName,
  });

  final String categoryName;
  final String modelName;
}

class _SizeQuoteNoteScreenState extends ConsumerState<SizeQuoteNoteScreen> {
  SizeQuoteNoteBook _book = const SizeQuoteNoteBook();
  List<_NoteTarget> _models = const [];
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
      final notes = await ref.read(sizeQuoteRepositoryProvider).loadQuoteNotes(
            refresh: true,
          );
      StandardUnitPriceCatalog? catalog;
      try {
        catalog = await ref
            .read(standardUnitPriceRepositoryProvider)
            .fetchCatalog();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _book = notes;
        _models = _targets(catalog, notes);
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

  List<_NoteTarget> _targets(
    StandardUnitPriceCatalog? catalog,
    SizeQuoteNoteBook book,
  ) {
    final seen = <String>{};
    final out = <_NoteTarget>[];
    void add(String category, String model) {
      final cat = category.trim();
      final name = model.trim();
      if (cat.isEmpty || name.isEmpty) return;
      final key = SizeQuoteNoteBook.key(cat, name);
      if (!seen.add(key)) return;
      out.add(_NoteTarget(categoryName: cat, modelName: name));
    }

    if (catalog != null) {
      for (final cat in catalog.orderedCategories) {
        for (final model in catalog.modelsFor(cat.id)) {
          add(cat.name, model.name);
        }
      }
    }
    for (final pair in kSizeQuoteNoteSeedModels) {
      add(pair.$1, pair.$2);
    }
    for (final key in book.models.keys) {
      final split = key.split('|');
      if (split.length < 2) continue;
      add(split.first, split.sublist(1).join('|'));
    }
    out.sort((a, b) {
      final byCat = a.categoryName.compareTo(b.categoryName);
      if (byCat != 0) return byCat;
      return a.modelName.compareTo(b.modelName);
    });
    return out;
  }

  String _modelPreview(_NoteTarget target) {
    if (_book.hasModel(target.categoryName, target.modelName)) {
      final body = _book.modelBody(target.categoryName, target.modelName).trim();
      if (body.isEmpty) return '저장된 내용 없음';
      return body.split('\n').first;
    }
    final fallback = sizeQuoteSpecNote(
      categoryName: target.categoryName,
      modelName: target.modelName,
    ).trim();
    if (fallback.isEmpty) return '기본 문구 없음';
    return '기본 · ${fallback.split('\n').first}';
  }

  Future<void> _editCommon() async {
    final initial = _book.hasCommon ? _book.common : kSizeQuoteBaseNote;
    final saved = await _edit(
      title: '공통 노트',
      initial: initial,
      help: '견적서 NOTE 1–7. 모든 모델 앞에 붙습니다.',
    );
    if (saved == null || !mounted) return;
    try {
      await ref.read(sizeQuoteRepositoryProvider).saveCommonQuoteNote(saved);
      if (!mounted) return;
      setState(() => _book = _book.putCommon(saved));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(koreanErrorMessage(e))),
      );
    }
  }

  Future<void> _editModel(_NoteTarget target) async {
    final stored = _book.hasModel(target.categoryName, target.modelName);
    final initial = stored
        ? _book.modelBody(target.categoryName, target.modelName)
        : sizeQuoteSpecNote(
            categoryName: target.categoryName,
            modelName: target.modelName,
          );
    final saved = await _edit(
      title: '${target.categoryName} · ${target.modelName}',
      initial: initial,
      help: '이 모델 견적서의 8번 이후 사양입니다. 공통 노트 뒤에 붙습니다.',
    );
    if (saved == null || !mounted) return;
    try {
      await ref.read(sizeQuoteRepositoryProvider).saveModelQuoteNote(
            categoryName: target.categoryName,
            modelName: target.modelName,
            body: saved,
          );
      if (!mounted) return;
      setState(
        () => _book = _book.putModel(
          categoryName: target.categoryName,
          modelName: target.modelName,
          body: saved,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(koreanErrorMessage(e))),
      );
    }
  }

  Future<String?> _edit({
    required String title,
    required String initial,
    required String help,
  }) {
    final ctrl = TextEditingController(text: initial);
    return showModalBottomSheet<String>(
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
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(help, style: TextStyle(color: Theme.of(ctx).hintColor)),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                minLines: 8,
                maxLines: 16,
                decoration: const InputDecoration(filled: true),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: const Text('저장'),
              ),
            ],
          ),
        );
      },
    ).whenComplete(ctrl.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('견적 노트')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    Text(
                      '공통 노트',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Card(
                      child: ListTile(
                        title: const Text('모든 견적서'),
                        subtitle: Text(
                          (_book.hasCommon ? _book.common : kSizeQuoteBaseNote)
                              .trim()
                              .split('\n')
                              .take(2)
                              .join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _editCommon();
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '모델별 노트',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final target in _models)
                      Card(
                        child: ListTile(
                          title: Text(target.modelName),
                          subtitle: Text(
                            '${target.categoryName} · ${_modelPreview(target)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.edit_outlined),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _editModel(target);
                          },
                        ),
                      ),
                  ],
                ),
    );
  }
}
