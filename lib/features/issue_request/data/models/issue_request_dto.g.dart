// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'issue_request_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IssueRequestDto _$IssueRequestDtoFromJson(Map<String, dynamic> json) =>
    IssueRequestDto(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      requestType: json['request_type'] as String,
      targetName: json['target_name'] as String,
      reason: json['reason'] as String?,
      status: json['status'] as String,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$IssueRequestDtoToJson(IssueRequestDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'request_type': instance.requestType,
      'target_name': instance.targetName,
      'reason': instance.reason,
      'status': instance.status,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

CreateIssueRequestRequestDto _$CreateIssueRequestRequestDtoFromJson(
  Map<String, dynamic> json,
) => CreateIssueRequestRequestDto(
  userId: (json['user_id'] as num).toInt(),
  requestType: json['request_type'] as String,
  targetName: json['target_name'] as String,
  reason: json['reason'] as String?,
);

Map<String, dynamic> _$CreateIssueRequestRequestDtoToJson(
  CreateIssueRequestRequestDto instance,
) => <String, dynamic>{
  'user_id': instance.userId,
  'request_type': instance.requestType,
  'target_name': instance.targetName,
  'reason': instance.reason,
};

CreateIssueRequestResponseDto _$CreateIssueRequestResponseDtoFromJson(
  Map<String, dynamic> json,
) => CreateIssueRequestResponseDto(
  id: (json['id'] as num).toInt(),
  status: json['status'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$CreateIssueRequestResponseDtoToJson(
  CreateIssueRequestResponseDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'status': instance.status,
  'created_at': instance.createdAt.toIso8601String(),
};

UpdateIssueRequestStatusRequestDto _$UpdateIssueRequestStatusRequestDtoFromJson(
  Map<String, dynamic> json,
) => UpdateIssueRequestStatusRequestDto(status: json['status'] as String);

Map<String, dynamic> _$UpdateIssueRequestStatusRequestDtoToJson(
  UpdateIssueRequestStatusRequestDto instance,
) => <String, dynamic>{'status': instance.status};
