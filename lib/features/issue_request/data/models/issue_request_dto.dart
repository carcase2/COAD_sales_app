import 'package:json_annotation/json_annotation.dart';

part 'issue_request_dto.g.dart';

@JsonSerializable()
class IssueRequestDto {
  const IssueRequestDto({
    required this.id,
    required this.userId,
    required this.requestType,
    required this.targetName,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;

  @JsonKey(name: 'user_id')
  final int userId;

  @JsonKey(name: 'request_type')
  final String requestType;

  @JsonKey(name: 'target_name')
  final String targetName;

  final String? reason;
  final String status;

  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  factory IssueRequestDto.fromJson(Map<String, dynamic> json) =>
      _$IssueRequestDtoFromJson(json);

  Map<String, dynamic> toJson() => _$IssueRequestDtoToJson(this);
}

@JsonSerializable()
class CreateIssueRequestRequestDto {
  const CreateIssueRequestRequestDto({
    required this.userId,
    required this.requestType,
    required this.targetName,
    required this.reason,
  });

  @JsonKey(name: 'user_id')
  final int userId;

  @JsonKey(name: 'request_type')
  final String requestType;

  @JsonKey(name: 'target_name')
  final String targetName;

  final String? reason;

  factory CreateIssueRequestRequestDto.fromJson(Map<String, dynamic> json) =>
      _$CreateIssueRequestRequestDtoFromJson(json);

  Map<String, dynamic> toJson() => _$CreateIssueRequestRequestDtoToJson(this);
}

@JsonSerializable()
class CreateIssueRequestResponseDto {
  const CreateIssueRequestResponseDto({
    required this.id,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String status;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  factory CreateIssueRequestResponseDto.fromJson(Map<String, dynamic> json) =>
      _$CreateIssueRequestResponseDtoFromJson(json);

  Map<String, dynamic> toJson() => _$CreateIssueRequestResponseDtoToJson(this);
}

@JsonSerializable()
class UpdateIssueRequestStatusRequestDto {
  const UpdateIssueRequestStatusRequestDto({required this.status});

  final String status;

  factory UpdateIssueRequestStatusRequestDto.fromJson(
    Map<String, dynamic> json,
  ) => _$UpdateIssueRequestStatusRequestDtoFromJson(json);

  Map<String, dynamic> toJson() =>
      _$UpdateIssueRequestStatusRequestDtoToJson(this);
}
