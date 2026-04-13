import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class ImageEditorScreen extends StatefulWidget {
  final File initialImage;

  const ImageEditorScreen({super.key, required this.initialImage});

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  final List<DrawingPath> _paths = [];
  
  Color _selectedColor = Colors.red;
  double _strokeWidth = 5.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('사진 편집 (주석)'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _paths.isEmpty ? null : () => setState(() => _paths.removeLast()),
            tooltip: '실행 취소',
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _saveImage,
            child: const Text('완료', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: InteractiveViewer(
                maxScale: 5.0,
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.file(widget.initialImage, fit: BoxFit.contain),
                      Positioned.fill(
                        child: GestureDetector(
                          onPanStart: (details) {
                            setState(() {
                              _paths.add(DrawingPath(
                                points: [details.localPosition],
                                color: _selectedColor,
                                strokeWidth: _strokeWidth,
                              ));
                            });
                          },
                          onPanUpdate: (details) {
                            setState(() {
                              if (_paths.isNotEmpty) {
                                _paths.last.points.add(details.localPosition);
                              }
                            });
                          },
                          child: CustomPaint(
                            painter: DrawingPainter(paths: _paths),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 도구 상자
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                _colorPicker(Colors.red),
                _colorPicker(Colors.yellow),
                _colorPicker(Colors.blue),
                const Spacer(),
                const Icon(Icons.line_weight_rounded, size: 20),
                Slider(
                  value: _strokeWidth,
                  min: 2,
                  max: 15,
                  onChanged: (val) => setState(() => _strokeWidth = val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorPicker(Color color) {
    bool isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)
          ],
        ),
      ),
    );
  }

  Future<void> _saveImage() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/annotated_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(buffer);

      if (mounted) Navigator.pop(context, file);
    } catch (e) {
      debugPrint('Save Error: $e');
    }
  }
}

class DrawingPath {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  DrawingPath({required this.points, required this.color, required this.strokeWidth});
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPath> paths;

  DrawingPainter({required this.paths});

  @override
  void paint(Canvas canvas, Size size) {
    for (var path in paths) {
      if (path.points.isEmpty) continue;

      final paint = Paint()
        ..color = path.color
        ..strokeWidth = path.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final p = Path();
      p.moveTo(path.points.first.dx, path.points.first.dy);
      for (int i = 1; i < path.points.length; i++) {
        p.lineTo(path.points[i].dx, path.points[i].dy);
      }
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}
