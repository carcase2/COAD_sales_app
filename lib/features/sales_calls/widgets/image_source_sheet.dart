import 'package:flutter/material.dart';

enum SalesCallImageSource { camera, gallery, files }

Future<SalesCallImageSource?> showSalesCallImageSourceSheet(
  BuildContext context, {
  String title = '사진 추가',
  bool includeFiles = false,
}) {
  return showModalBottomSheet<SalesCallImageSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(ctx, SalesCallImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(includeFiles ? '사진 여러 장 선택' : '앨범·파일에서 선택'),
              subtitle: includeFiles
                  ? const Text('한 번에 여러 장을 고를 수 있습니다')
                  : null,
              onTap: () => Navigator.pop(ctx, SalesCallImageSource.gallery),
            ),
            if (includeFiles)
              ListTile(
                leading: const Icon(Icons.attach_file_rounded),
                title: const Text('파일 여러 개 선택'),
                subtitle: const Text('PDF 등, 한 번에 여러 개'),
                onTap: () => Navigator.pop(ctx, SalesCallImageSource.files),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
