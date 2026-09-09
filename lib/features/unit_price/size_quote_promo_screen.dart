import 'dart:async';
import 'dart:typed_data';

import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/core/widgets/cached_app_image.dart';
import 'package:coad_customer_calls/data/size_quote_repository.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_document.dart';
import 'package:coad_customer_calls/features/unit_price/standard_unit_price_models.dart';
import 'package:coad_customer_calls/features/unit_price/standard_unit_price_repository.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

Future<void> pushSizeQuotePromoScreen(
  BuildContext context, {
  StandardUnitPriceCatalog? catalog,
  String? modelId,
  String? modelName,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => SizeQuotePromoScreen(
        catalog: catalog,
        initialModelId: modelId,
        initialModelName: modelName,
      ),
    ),
  );
}

class SizeQuotePromoScreen extends ConsumerStatefulWidget {
  const SizeQuotePromoScreen({
    super.key,
    this.catalog,
    this.initialModelId,
    this.initialModelName,
  });

  final StandardUnitPriceCatalog? catalog;
  final String? initialModelId;
  final String? initialModelName;

  @override
  ConsumerState<SizeQuotePromoScreen> createState() =>
      _SizeQuotePromoScreenState();
}

class _SizeQuotePromoScreenState extends ConsumerState<SizeQuotePromoScreen> {
  StandardUnitPriceCatalog? _catalog;
  String? _categoryId;
  String? _modelId;
  String _modelName = '';
  List<SizeQuotePromoImage> _items = const [];
  bool _loading = true;
  bool _busy = false;
  Object? _error;

  SizeQuoteRepository get _repo => ref.read(sizeQuoteRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _catalog = widget.catalog;
    _modelId = widget.initialModelId;
    _modelName = widget.initialModelName ?? '';
    if (_catalog != null && _modelId != null) {
      for (final m in _catalog!.models) {
        if (m.id == _modelId) {
          _categoryId = m.categoryId;
          _modelName = m.name;
          break;
        }
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_bootstrap());
    });
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var catalog = _catalog;
      catalog ??= await ref.read(standardUnitPriceRepositoryProvider).fetchCatalog();
      var categoryId = _categoryId;
      var modelId = _modelId;
      var modelName = _modelName;
      if (catalog.orderedCategories.isNotEmpty) {
        categoryId ??= catalog.orderedCategories.first.id;
        final inCat = catalog.modelsFor(categoryId);
        if (modelId == null || !inCat.any((m) => m.id == modelId)) {
          final first = inCat.isEmpty ? null : inCat.first;
          modelId = first?.id;
          modelName = first?.name ?? '';
        } else {
          modelName = inCat.firstWhere((m) => m.id == modelId).name;
        }
      }
      final items = (modelId ?? '').isEmpty
          ? const <SizeQuotePromoImage>[]
          : await _repo.listPromoImages(modelId!);
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _categoryId = categoryId;
        _modelId = modelId;
        _modelName = modelName;
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadImages() async {
    final modelId = _modelId;
    if (modelId == null || modelId.isEmpty) {
      setState(() => _items = const []);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.listPromoImages(modelId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _selectCategory(String id) {
    final catalog = _catalog;
    if (catalog == null) return;
    final inCat = catalog.modelsFor(id);
    final first = inCat.isEmpty ? null : inCat.first;
    setState(() {
      _categoryId = id;
      _modelId = first?.id;
      _modelName = first?.name ?? '';
    });
    unawaited(_loadImages());
  }

  void _selectModel(StandardUnitPriceModel model) {
    setState(() {
      _modelId = model.id;
      _modelName = model.name;
    });
    unawaited(_loadImages());
  }

  Future<Uint8List> _compress(String path) async {
    final compressed = await FlutterImageCompress.compressWithFile(
      path,
      quality: 78,
      minWidth: 1600,
      minHeight: 1600,
    );
    if (compressed != null && compressed.isNotEmpty) return compressed;
    return XFile(path).readAsBytes();
  }

  Future<ImageSource?> _pickSource({required bool allowMulti}) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(allowMulti ? '앨범에서 여러 장' : '앨범에서 고르기'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('카메라로 찍기'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _add() async {
    final modelId = _modelId;
    if (_busy || modelId == null) return;
    final source = await _pickSource(allowMulti: true);
    if (source == null || !mounted) return;
    final picker = ImagePicker();
    final files = <XFile>[];
    if (source == ImageSource.gallery) {
      files.addAll(await picker.pickMultiImage(imageQuality: 88));
    } else {
      final shot = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
      );
      if (shot != null) files.add(shot);
    }
    if (files.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final user = ref.read(authControllerProvider);
      for (final shot in files) {
        await _repo.uploadPromoImage(
          modelId: modelId,
          bytes: await _compress(shot.path),
          fileName: shot.name,
          title: shot.name.replaceAll(RegExp(r'\.[A-Za-z0-9]+$'), ''),
          createdBy: user?.name ?? user?.id,
        );
      }
      await _loadImages();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _replace(SizeQuotePromoImage image) async {
    if (_busy) return;
    final source = await _pickSource(allowMulti: false);
    if (source == null || !mounted) return;
    final shot = await ImagePicker().pickImage(
      source: source,
      imageQuality: 88,
    );
    if (shot == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.replacePromoImage(
        image: image,
        bytes: await _compress(shot.path),
        fileName: shot.name,
      );
      await _loadImages();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename(SizeQuotePromoImage image) async {
    final ctrl = TextEditingController(text: image.title);
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('제목 수정'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '견적서 다음장에 보일 이름',
            labelText: '제목',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (next == null || !mounted) return;
    try {
      await _repo.updatePromoImage(id: image.id, title: next);
      await _loadImages();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
    }
  }

  Future<void> _delete(SizeQuotePromoImage image) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('홍보 이미지 삭제'),
        content: Text(
          '${image.title.trim().isEmpty ? '이 이미지' : '「${image.title.trim()}」'}를 삭제할까요?\n이 모델 견적서 다음장에서 빠집니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.deletePromoImage(image);
      await _loadImages();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
    }
  }

  Future<void> _editSheet(SizeQuotePromoImage image) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('크게 보기'),
              onTap: () => Navigator.pop(ctx, 'preview'),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('사진 바꾸기'),
              onTap: () => Navigator.pop(ctx, 'replace'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('제목 수정'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(ctx).colorScheme.error,
              ),
              title: Text(
                '삭제',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'preview':
        await _preview(image);
      case 'replace':
        await _replace(image);
      case 'rename':
        await _rename(image);
      case 'delete':
        await _delete(image);
    }
  }

  Future<void> _preview(SizeQuotePromoImage image) async {
    final url = _repo.publicPromoUrl(image.storagePath);
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      image.title.trim().isEmpty ? _modelName : image.title.trim(),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.62,
              ),
              child: InteractiveViewer(
                child: CachedAppImage(url: url, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        unawaited(_replace(image));
                      },
                      child: const Text('사진 바꾸기'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        unawaited(_rename(image));
                      },
                      child: const Text('제목 수정'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        unawaited(_delete(image));
                      },
                      child: const Text('삭제'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final next = [..._items];
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    setState(() => _items = next);
    try {
      for (var i = 0; i < next.length; i++) {
        await _repo.updatePromoImage(id: next[i].id, sortOrder: i);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
      await _loadImages();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final catalog = _catalog;
    final models = (_categoryId == null || catalog == null)
        ? const <StandardUnitPriceModel>[]
        : catalog.modelsFor(_categoryId!);
    return Scaffold(
      appBar: AppBar(
        title: const Text('홍보 이미지'),
        actions: [
          IconButton(
            tooltip: '추가',
            onPressed: _busy || _modelId == null ? null : () => unawaited(_add()),
            icon: const Icon(Icons.add_photo_alternate_outlined),
          ),
        ],
      ),
      floatingActionButton: _modelId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : () => unawaited(_add()),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
              label: const Text('추가'),
            ),
      body: Column(
        children: [
          if (catalog != null) ...[
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                itemCount: catalog.orderedCategories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final cat = catalog.orderedCategories[i];
                  final selected = cat.id == _categoryId;
                  return ChoiceChip(
                    label: Text(cat.name),
                    selected: selected,
                    onSelected: (_) => _selectCategory(cat.id),
                  );
                },
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                itemCount: models.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final model = models[i];
                  final selected = model.id == _modelId;
                  return FilterChip(
                    selected: selected,
                    label: Text(model.name),
                    onSelected: (_) => _selectModel(model),
                  );
                },
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _modelName.isEmpty
                    ? '모델을 고른 뒤 이미지를 추가·수정·삭제하세요'
                    : '$_modelName · 견적서 다음장 · ${_items.length}장',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const AppLoading(message: '홍보 이미지 불러오는 중…')
                : _error != null
                ? AppErrorState(
                    message: koreanErrorMessage(_error!),
                    onRetry: _loadImages,
                  )
                : _modelId == null
                ? const AppEmpty(
                    icon: Icons.collections_outlined,
                    message: '모델을 먼저 선택하세요',
                  )
                : _items.isEmpty
                ? AppEmpty(
                    icon: Icons.collections_outlined,
                    message: '$_modelName 홍보 이미지가 없습니다',
                    detail: '이 모델 견적서 다음장에 붙을 사진을 추가하세요.',
                    actionLabel: '이미지 추가',
                    onAction: () => unawaited(_add()),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                    itemCount: _items.length,
                    onReorderItem: _reorder,
                    itemBuilder: (context, i) {
                      final image = _items[i];
                      final url = _repo.publicPromoUrl(image.storagePath);
                      return Card(
                        key: ValueKey(image.id),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => unawaited(_preview(image)),
                          onLongPress: () => unawaited(_editSheet(image)),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 88,
                                    height: 88,
                                    child: CachedAppImage(
                                      url: url,
                                      memCacheWidth: 220,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        image.title.trim().isEmpty
                                            ? '이미지 ${i + 1}'
                                            : image.title.trim(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${i + 1}번째 장 · 탭하면 크게 보기',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: '수정',
                                  onPressed: () => unawaited(_editSheet(image)),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: '삭제',
                                  onPressed: () => unawaited(_delete(image)),
                                  icon: const Icon(Icons.delete_outline_rounded),
                                ),
                                ReorderableDragStartListener(
                                  index: i,
                                  child: const Icon(Icons.drag_handle_rounded),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
