import 'dart:math';
import 'package:coad_customer_calls/data/shutter_repository.dart';
import 'package:coad_customer_calls/features/quoter/shutter_calculator.dart';
import 'package:coad_customer_calls/models/shutter_models.dart';
import 'package:coad_customer_calls/models/similar_shutter_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ScoredEstimate {
  final SimilarShutterEstimate estimate;
  final int score;

  ScoredEstimate({required this.estimate, required this.score});
}

final similarEstimatesProvider = FutureProvider.family<List<ScoredEstimate>, ShutterEstimateInput>((ref, input) async {
  if (input.widthMm <= 0 || input.heightMm <= 0) return [];
  
  // 철제방화 또는 스크린방화 모델인 경우에만 작동
  if (input.type != ShutterType.fireSteel && input.type != ShutterType.fireScreen) {
    return [];
  }

  final repo = ref.read(shutterRepositoryProvider);
  final dbInfo = ShutterCalculator.getDbInfo(input.type);
  
  // shutter_models에서 일치하는 id 찾기
  final modelId = await repo.fetchShutterModelId(
    dbInfo['category']!, 
    dbInfo['model_type'],
  );
  
  if (modelId == null) return [];

  // 해당 모델의 이전 견적 데이터 가져오기
  final rawEstimates = await repo.fetchSimpleEstimates(modelId);
  final estimates = rawEstimates.map((e) => SimilarShutterEstimate.fromJson(e)).toList();

  // 유사도 점수 계산
  final scored = estimates.map((est) {
    final wDiff = (est.width - input.widthMm).abs();
    final hDiff = (est.height - input.heightMm).abs();
    
    final wScore = max(0, 1000 - wDiff.toInt());
    final hScore = max(0, 1000 - hDiff.toInt());
    const modelBonus = 500; // 모델 일치 보너스
    
    return ScoredEstimate(
      estimate: est,
      score: wScore + hScore + modelBonus,
    );
  }).toList();

  // 점수 높은 순으로 5개 추출
  scored.sort((a, b) => b.score.compareTo(a.score));
  return scored.take(5).toList();
});
