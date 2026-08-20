import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:coad_customer_calls/data/business_card_detect.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 한국 명함 표준 대략 90×50mm.
const double kBusinessCardAspect = 90 / 50;

/// 사진에서 명함 영역만 남기고 자른 파일 경로를 반환한다. 취소 시 null.
Future<String?> cropBusinessCardImage(
  BuildContext context, {
  required String imagePath,
}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute<String>(
      builder: (_) => BusinessCardCropScreen(imagePath: imagePath),
    ),
  );
}

class BusinessCardCropScreen extends ConsumerStatefulWidget {
  const BusinessCardCropScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  ConsumerState<BusinessCardCropScreen> createState() =>
      _BusinessCardCropScreenState();
}

enum _DragKind { none, move, nw, ne, sw, se }

class _BusinessCardCropScreenState
    extends ConsumerState<BusinessCardCropScreen> {
  ui.Image? _image;
  Uint8List? _bytes;
  Rect _crop = Rect.zero;
  Size _viewSize = Size.zero;
  _DragKind _drag = _DragKind.none;
  Offset _dragStart = Offset.zero;
  Rect _cropAtStart = Rect.zero;
  bool _saving = false;
  bool _lockAspect = false;
  bool _detecting = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _image = frame.image;
    });
    await _detectAndApply();
  }

  Future<void> _detectAndApply() async {
    final bytes = _bytes;
    if (bytes == null) return;
    setState(() => _detecting = true);
    NormalizedCardBox? box = await detectBusinessCardBox(bytes);
    if (box == null && mounted) {
      try {
        box = await ref
            .read(aiExtractorServiceProvider)
            .detectBusinessCardBoxAi(bytes);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _detecting = false);
    if (box == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('테두리를 찾지 못했습니다. 네모를 직접 맞춰 주세요.')),
      );
      return;
    }
    _applyNormalizedBox(box);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          box.isPortrait ? '세로 명함 테두리를 맞췄습니다.' : '가로 명함 테두리를 맞췄습니다.',
        ),
      ),
    );
  }

  void _applyNormalizedBox(NormalizedCardBox box) {
    if (_viewSize == Size.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyNormalizedBox(box);
      });
      return;
    }
    final disp = _imageDisplayRect(_viewSize);
    if (disp.isEmpty) return;
    final next = Rect.fromLTRB(
      disp.left + box.left * disp.width,
      disp.top + box.top * disp.height,
      disp.left + box.right * disp.width,
      disp.top + box.bottom * disp.height,
    );
    setState(() {
      _lockAspect = false;
      _crop = _clampTo(next, disp);
    });
  }

  Rect _imageDisplayRect(Size view) {
    final img = _image;
    if (img == null || view.isEmpty) return Rect.zero;
    final iw = img.width.toDouble();
    final ih = img.height.toDouble();
    final scale = math.min(view.width / iw, view.height / ih);
    final w = iw * scale;
    final h = ih * scale;
    return Rect.fromLTWH(
      (view.width - w) / 2,
      (view.height - h) / 2,
      w,
      h,
    );
  }

  void _ensureDefaultCrop(Size view) {
    if (_crop != Rect.zero || _image == null || view.isEmpty) return;
    final disp = _imageDisplayRect(view);
    if (disp.isEmpty) return;
    var w = disp.width * 0.86;
    var h = w / kBusinessCardAspect;
    if (h > disp.height * 0.86) {
      h = disp.height * 0.86;
      w = h * kBusinessCardAspect;
    }
    _crop = Rect.fromCenter(center: disp.center, width: w, height: h);
  }

  _DragKind _hit(Offset p) {
    const pad = 22.0;
    bool near(Offset a) => (a - p).distance <= pad;
    if (near(_crop.topLeft)) return _DragKind.nw;
    if (near(_crop.topRight)) return _DragKind.ne;
    if (near(_crop.bottomLeft)) return _DragKind.sw;
    if (near(_crop.bottomRight)) return _DragKind.se;
    if (_crop.inflate(8).contains(p)) return _DragKind.move;
    return _DragKind.none;
  }

  void _onScaleStart(ScaleStartDetails d) {
    _drag = _hit(d.localFocalPoint);
    _dragStart = d.localFocalPoint;
    _cropAtStart = _crop;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_drag == _DragKind.none) return;
    final disp = _imageDisplayRect(_viewSize);
    final delta = d.localFocalPoint - _dragStart;
    var next = _cropAtStart;

    if (_drag == _DragKind.move) {
      next = next.shift(delta);
    } else {
      var l = next.left;
      var t = next.top;
      var r = next.right;
      var b = next.bottom;
      switch (_drag) {
        case _DragKind.nw:
          l += delta.dx;
          t += delta.dy;
        case _DragKind.ne:
          r += delta.dx;
          t += delta.dy;
        case _DragKind.sw:
          l += delta.dx;
          b += delta.dy;
        case _DragKind.se:
          r += delta.dx;
          b += delta.dy;
        default:
          break;
      }
      if (_lockAspect) {
        final w = (r - l).abs().clamp(72.0, disp.width);
        final h = w / kBusinessCardAspect;
        next = switch (_drag) {
          _DragKind.se => Rect.fromLTWH(_cropAtStart.left, _cropAtStart.top, w, h),
          _DragKind.nw => Rect.fromLTRB(
              _cropAtStart.right - w,
              _cropAtStart.bottom - h,
              _cropAtStart.right,
              _cropAtStart.bottom,
            ),
          _DragKind.ne => Rect.fromLTRB(
              _cropAtStart.left,
              _cropAtStart.bottom - h,
              _cropAtStart.left + w,
              _cropAtStart.bottom,
            ),
          _DragKind.sw => Rect.fromLTRB(
              _cropAtStart.right - w,
              _cropAtStart.top,
              _cropAtStart.right,
              _cropAtStart.top + h,
            ),
          _ => next,
        };
      } else {
        next = Rect.fromLTRB(l, t, r, b).normalize;
      }
    }

    next = _clampTo(next, disp);
    setState(() => _crop = next);
  }

  Rect _clampTo(Rect crop, Rect bounds) {
    var c = crop.normalize;
    const minW = 72.0;
    const minH = 40.0;
    if (c.width < minW) {
      c = Rect.fromLTWH(c.left, c.top, minW, _lockAspect ? minW / kBusinessCardAspect : minH);
    }
    if (c.height < minH) {
      final h = minH;
      final w = _lockAspect ? h * kBusinessCardAspect : math.max(c.width, minW);
      c = Rect.fromLTWH(c.left, c.top, w, h);
    }
    if (c.width > bounds.width) {
      final w = bounds.width;
      c = Rect.fromLTWH(bounds.left, c.top, w, _lockAspect ? w / kBusinessCardAspect : c.height);
    }
    if (c.height > bounds.height) {
      final h = bounds.height;
      c = Rect.fromLTWH(c.left, bounds.top, _lockAspect ? h * kBusinessCardAspect : c.width, h);
    }
    var dx = 0.0;
    var dy = 0.0;
    if (c.left < bounds.left) dx = bounds.left - c.left;
    if (c.top < bounds.top) dy = bounds.top - c.top;
    if (c.right > bounds.right) dx = bounds.right - c.right;
    if (c.bottom > bounds.bottom) dy = bounds.bottom - c.bottom;
    return c.shift(Offset(dx, dy));
  }

  Future<void> _confirm() async {
    final img = _image;
    if (img == null || _saving) return;
    final disp = _imageDisplayRect(_viewSize);
    if (disp.isEmpty || _crop.width < 8 || _crop.height < 8) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      final scaleX = img.width / disp.width;
      final scaleY = img.height / disp.height;
      final src = Rect.fromLTWH(
        (_crop.left - disp.left) * scaleX,
        (_crop.top - disp.top) * scaleY,
        _crop.width * scaleX,
        _crop.height * scaleY,
      ).intersect(Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()));
      final outW = math.max(1, src.width.round());
      final outH = math.max(1, src.height.round());

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        img,
        src,
        Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );
      final picture = recorder.endRecording();
      final cropped = await picture.toImage(outW, outH);
      final png = await cropped.toByteData(format: ui.ImageByteFormat.png);
      cropped.dispose();
      if (png == null) throw StateError('자르기에 실패했습니다.');

      final dir = await getTemporaryDirectory();
      final outPath = p.join(
        dir.path,
        'card_crop_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await File(outPath).writeAsBytes(png.buffer.asUint8List(), flush: true);
      if (!mounted) return;
      Navigator.of(context).pop(outPath);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('자르기 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          '명함만 자르기',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          if (!_detecting)
            TextButton(
              onPressed: _saving ? null : _detectAndApply,
              child: const Text('다시 찾기', style: TextStyle(color: Colors.white)),
            ),
          TextButton(
            onPressed: _saving || _detecting ? null : _confirm,
            child: Text(
              _saving ? '저장 중…' : '이 영역만 저장',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: img == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_detecting) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _viewSize = constraints.biggest;
                      _ensureDefaultCrop(_viewSize);
                      return GestureDetector(
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: _onScaleUpdate,
                        onScaleEnd: (_) => _drag = _DragKind.none,
                        child: CustomPaint(
                          painter: _CropPainter(
                            image: img,
                            display: _imageDisplayRect(_viewSize),
                            crop: _crop,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            '명함 비율 고정 (90×50 가로)',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          value: _lockAspect,
                          onChanged: (v) => setState(() => _lockAspect = v),
                        ),
                        Text(
                          _detecting
                              ? '세로·가로 명함 테두리를 찾는 중…'
                              : '테두리를 맞췄습니다. 틀리면 네모를 조정한 뒤 저장하세요.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter({
    required this.image,
    required this.display,
    required this.crop,
  });

  final ui.Image image;
  final Rect display;
  final Rect crop;

  @override
  void paint(Canvas canvas, Size size) {
    if (display.isEmpty) return;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      display,
      Paint()..filterQuality = FilterQuality.medium,
    );

    final dim = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(crop, const Radius.circular(6)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      dim,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(crop, const Radius.circular(6)),
      border,
    );

    final handle = Paint()..color = Colors.white;
    const s = 14.0;
    for (final c in [crop.topLeft, crop.topRight, crop.bottomLeft, crop.bottomRight]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: s, height: s),
          const Radius.circular(3),
        ),
        handle,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CropPainter old) =>
      old.crop != crop || old.display != display || old.image != image;
}

extension on Rect {
  Rect get normalize {
    return Rect.fromLTRB(
      math.min(left, right),
      math.min(top, bottom),
      math.max(left, right),
      math.max(top, bottom),
    );
  }
}
