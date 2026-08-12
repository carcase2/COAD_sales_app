import 'package:coad_customer_calls/models/checksheet_archive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ChecksheetSearchResult groups site JSON', () {
    final result = ChecksheetSearchResult.fromJson({
      'query': '화성',
      'total_sites': 1,
      'total_attachments': 2,
      'offset': 0,
      'limit': 50,
      'next_offset': null,
      'sites': [
        {
          'site_key': '화성 분토길 50',
          'site_name': '화성 분토길 50',
          'reg_date': '2026-07-15',
          'year': 2026,
          'month': 7,
          'checksheet_count': 2,
          'thumbnail_media_path': '/api/archive/media?id=a',
          'attachments': [
            {
              'id': 'a',
              'original_name': '1.jpg',
              'mime': 'image/jpeg',
              'file_size': 100,
              'r2_key': 'data/sites/2026/07/15/화성 분토길 50/04_체크시트/TP1_x.jpg',
              'uploaded_at': '2026-08-12T00:00:00Z',
              'media_path': '/api/archive/media?id=a',
            },
            {
              'id': 'b',
              'original_name': '2.jpg',
              'media_path': '/api/archive/media?id=b',
            },
          ],
        },
      ],
    });

    expect(result.sites, hasLength(1));
    expect(result.sites.first.siteName, '화성 분토길 50');
    expect(result.sites.first.attachments, hasLength(2));
    expect(result.sites.first.attachments.first.mediaPath, contains('id=a'));
    expect(result.hasMore, isFalse);
  });
}
