import 'package:coad_customer_calls/features/quoter/quoter_type_style.dart';
import 'package:coad_customer_calls/features/unit_price/standard_unit_price.dart';
import 'package:coad_customer_calls/features/unit_price/standard_unit_price_models.dart';
import 'package:coad_customer_calls/models/shutter_models.dart';

/// 사이즈를 먼저 정한 뒤 고르는 모델 한 줄.
class SizeFirstOffer {
  const SizeFirstOffer({
    required this.categoryId,
    required this.categoryName,
    required this.modelId,
    required this.modelName,
    required this.color,
    required this.quote,
    this.shutterType,
  });

  final String categoryId;
  final String categoryName;
  final String modelId;
  final String modelName;
  final String color;
  final SameSizeModelQuote quote;
  final ShutterType? shutterType;

  bool get isShutter => shutterType != null;
}

/// 표준단가 모델 이름에 셔터 견적기 종류가 들어 있으면 그 종류.
/// 더 긴 이름(내풍압단열)이 짧은 이름(내풍압)보다 먼저 맞는다.
ShutterType? shutterTypeForModelName(String name) {
  final key = name.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  if (key.isEmpty) return null;
  final labels = [
    for (final type in ShutterType.values)
      (
        type: type,
        label: QuoterTypeStyle.label(
          type,
        ).replaceAll(RegExp(r'\s+'), '').toLowerCase(),
      ),
  ]..sort((a, b) => b.label.length.compareTo(a.label.length));
  for (final item in labels) {
    if (item.label.isEmpty) continue;
    if (key == item.label || key.contains(item.label)) return item.type;
  }
  return null;
}

/// 단가 있는 모델이 앞. 같은 금액이면 이름순. 불가·없음은 뒤.
int compareSizeQuotes(SameSizeModelQuote a, SameSizeModelQuote b) {
  final ap = a.price;
  final bp = b.price;
  if (ap == null && bp == null) return a.modelName.compareTo(b.modelName);
  if (ap == null) return 1;
  if (bp == null) return -1;
  final byPrice = ap.compareTo(bp);
  if (byPrice != 0) return byPrice;
  return a.modelName.compareTo(b.modelName);
}

/// 폭·높이 하나로 분류 안 모델을 싼 순으로 모은다.
List<SizeFirstOffer> sizeFirstOffers({
  required List<StandardUnitPriceCategory> categories,
  required List<StandardUnitPriceModel> models,
  required Map<String, List<StandardPriceCell>> cellsByModel,
  required int widthMm,
  required int heightMm,
  String? categoryId,
}) {
  if (widthMm <= 0 || heightMm <= 0) return const [];
  final chosen = categoryId == null || categoryId.isEmpty
      ? categories
      : categories.where((cat) => cat.id == categoryId);
  final offers = <SizeFirstOffer>[];
  for (final cat in chosen) {
    final inCat = models.where((model) => model.categoryId == cat.id).toList();
    if (inCat.isEmpty) continue;
    final quotes = sameSizeQuotes(
      models: [
        for (final model in inCat)
          (id: model.id, name: model.name, color: model.color),
      ],
      cellsByModel: cellsByModel,
      widthMm: widthMm,
      heightMm: heightMm,
      ceilingHeights: cat.name == '차고문',
    );
    final byId = {for (final quote in quotes) quote.modelId: quote};
    for (final model in inCat) {
      final quote = byId[model.id];
      if (quote == null) continue;
      offers.add(
        SizeFirstOffer(
          categoryId: cat.id,
          categoryName: cat.name,
          modelId: model.id,
          modelName: model.name,
          color: model.color,
          quote: quote,
          shutterType: shutterTypeForModelName(model.name),
        ),
      );
    }
  }
  offers.sort((a, b) {
    final byPrice = compareSizeQuotes(a.quote, b.quote);
    if (byPrice != 0) return byPrice;
    final byCat = a.categoryName.compareTo(b.categoryName);
    if (byCat != 0) return byCat;
    return a.modelName.compareTo(b.modelName);
  });
  return offers;
}
