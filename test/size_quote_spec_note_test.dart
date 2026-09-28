import 'package:coad_customer_calls/features/unit_price/size_quote_spec_note.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('공통 노트 1–7 뒤에 모델별 spec 노트가 붙는다', () {
    final premium = sizeQuotePaperNote(
      categoryName: '스피드도어',
      modelName: 'PREMIUM',
    );
    expect(premium, contains('1. VAT. 별도'));
    expect(premium, contains('7. 양중 필요시 추가 비용발생'));
    expect(premium, contains('COAD-3'));
    expect(premium, contains('복구기능적용'));
    expect(premium, isNot(contains('COAD-1')));

    expect(
      sizeQuoteSpecNote(categoryName: '스피드도어', modelName: 'STANDARD'),
      contains('COAD-1'),
    );
    expect(
      sizeQuoteSpecNote(categoryName: '스피드도어', modelName: 'DELUEX'),
      contains('ALTAX MOTOR'),
    );
    expect(
      sizeQuoteSpecNote(categoryName: '스피드도어', modelName: 'VE STANDARD'),
      contains('COAD-VE'),
    );
    expect(
      sizeQuoteSpecNote(categoryName: '차고문', modelName: 'PREMIUM(샤틴펄)'),
      contains('사틴펄'),
    );
    expect(
      sizeQuoteSpecNote(categoryName: '차고문', modelName: 'STANDARD(우드판넬)'),
      contains('우드줄무늬'),
    );
    expect(
      sizeQuoteSpecNote(categoryName: '셔터', modelName: '이중압출'),
      contains('GUIDE RAIL - SUS304'),
    );
    expect(
      sizeQuoteSpecNote(categoryName: '셔터', modelName: '내풍압단열 비와이'),
      contains('140 X 5T'),
    );
    expect(
      sizeQuoteSpecNote(categoryName: '없는분류', modelName: '기타'),
      isEmpty,
    );
  });

  test('DB에 저장된 공통·모델 노트가 코드 기본값보다 우선한다', () {
    const book = SizeQuoteNoteBook(
      hasCommon: true,
      common: 'NOTE\n1. 저장된 공통',
      models: {'스피드도어|premium': '8. 저장된 사양'},
    );
    final note = sizeQuotePaperNote(
      categoryName: '스피드도어',
      modelName: 'PREMIUM',
      book: book,
    );
    expect(note, contains('1. 저장된 공통'));
    expect(note, contains('8. 저장된 사양'));
    expect(note, isNot(contains('COAD-3')));
    expect(note, isNot(contains('양중 필요시')));
  });

  test('작성자가 적은 메모는 모델 노트 뒤에 한 번만 붙는다', () {
    final note = sizeQuotePaperNote(
      categoryName: '스피드도어',
      modelName: 'PREMIUM',
      extra: '현장 협의',
    );
    expect(note.indexOf('COAD-3'), lessThan(note.indexOf('현장 협의')));
    expect('현장 협의'.allMatches(note).length, 1);
  });
}
