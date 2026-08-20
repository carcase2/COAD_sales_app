enum BusinessCardListFilter { all, mine, privateOnly, blacklisted }

enum BusinessCardVisibility {
  team,
  private;

  static BusinessCardVisibility parse(Object? raw) {
    final v = raw?.toString().trim().toLowerCase();
    if (v == 'private') return BusinessCardVisibility.private;
    return BusinessCardVisibility.team;
  }

  String get dbValue => name;

  String get label =>
      this == BusinessCardVisibility.private ? '나만 보기' : '팀 공유';
}

class BusinessCard {
  const BusinessCard({
    required this.id,
    required this.name,
    required this.company,
    required this.title,
    required this.mobilePhone,
    required this.officePhone,
    this.faxPhone = '',
    required this.email,
    required this.address,
    required this.memo,
    required this.imageUrl,
    required this.visibility,
    this.isBlacklisted = false,
    required this.createdBy,
    required this.createdByName,
    required this.updatedBy,
    required this.updatedByName,
    required this.createdAt,
    required this.updatedAt,
    this.commentCount = 0,
  });

  final String id;
  final String name;
  final String company;
  final String title;
  final String mobilePhone;
  final String officePhone;
  final String faxPhone;
  final String email;
  final String address;
  final String memo;
  final String imageUrl;
  final BusinessCardVisibility visibility;
  final bool isBlacklisted;
  final String createdBy;
  final String createdByName;
  final String updatedBy;
  final String updatedByName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int commentCount;

  bool get isPrivate => visibility == BusinessCardVisibility.private;

  String get displayName {
    if (name.isNotEmpty) return name;
    if (company.isNotEmpty) return company;
    return '(이름 없음)';
  }

  String get initials {
    final src = displayName.trim();
    if (src.isEmpty) return '?';
    return src.substring(0, src.length >= 2 ? 2 : 1);
  }

  String get primaryPhone =>
      mobilePhone.trim().isNotEmpty ? mobilePhone : officePhone;

  String get subtitle {
    return [
      if (company.isNotEmpty && name.isNotEmpty) company,
      if (title.isNotEmpty) title,
    ].join(' · ');
  }

  factory BusinessCard.fromJson(Map<String, dynamic> json) {
    final comments = json['business_card_comments'];
    var commentCount = _asInt(json['comment_count']);
    if (commentCount == 0 && comments is List) {
      commentCount = comments.where((e) {
        if (e is! Map) return true;
        return e['deleted_at'] == null;
      }).length;
    }
    return BusinessCard(
      id: _str(json['id']),
      name: _str(json['name']),
      company: _str(json['company']),
      title: _str(json['title']),
      mobilePhone: _str(json['mobile_phone']),
      officePhone: _str(json['office_phone']),
      faxPhone: _str(json['fax_phone']),
      email: _str(json['email']),
      address: _str(json['address']),
      memo: _str(json['memo']),
      imageUrl: _str(json['image_url']),
      visibility: BusinessCardVisibility.parse(json['visibility']),
      isBlacklisted: _asBool(json['is_blacklisted']),
      createdBy: _str(json['created_by']),
      createdByName: _str(json['created_by_name']),
      updatedBy: _str(json['updated_by']),
      updatedByName: _str(json['updated_by_name']),
      createdAt: _dt(json['created_at']),
      updatedAt: _dt(json['updated_at']),
      commentCount: commentCount,
    );
  }

  Map<String, dynamic> toInsertJson({
    required String userId,
    required String userName,
  }) {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name.trim(),
      'company': company.trim(),
      'title': title.trim(),
      'mobile_phone': mobilePhone.trim(),
      'office_phone': officePhone.trim(),
      'fax_phone': faxPhone.trim(),
      'email': email.trim(),
      'address': address.trim(),
      'memo': memo.trim(),
      'image_url': imageUrl.trim(),
      'visibility': visibility.dbValue,
      'is_blacklisted': isBlacklisted,
      'created_by': userId,
      'created_by_name': userName,
      'updated_by': userId,
      'updated_by_name': userName,
    };
  }

  Map<String, dynamic> toUpdateJson({
    required String userId,
    required String userName,
  }) {
    return {
      'name': name.trim(),
      'company': company.trim(),
      'title': title.trim(),
      'mobile_phone': mobilePhone.trim(),
      'office_phone': officePhone.trim(),
      'fax_phone': faxPhone.trim(),
      'email': email.trim(),
      'address': address.trim(),
      'memo': memo.trim(),
      'image_url': imageUrl.trim(),
      'visibility': visibility.dbValue,
      'is_blacklisted': isBlacklisted,
      'updated_by': userId,
      'updated_by_name': userName,
    };
  }

  BusinessCard copyWith({
    String? id,
    String? name,
    String? company,
    String? title,
    String? mobilePhone,
    String? officePhone,
    String? faxPhone,
    String? email,
    String? address,
    String? memo,
    String? imageUrl,
    BusinessCardVisibility? visibility,
    bool? isBlacklisted,
    String? createdBy,
    String? createdByName,
    String? updatedBy,
    String? updatedByName,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? commentCount,
  }) {
    return BusinessCard(
      id: id ?? this.id,
      name: name ?? this.name,
      company: company ?? this.company,
      title: title ?? this.title,
      mobilePhone: mobilePhone ?? this.mobilePhone,
      officePhone: officePhone ?? this.officePhone,
      faxPhone: faxPhone ?? this.faxPhone,
      email: email ?? this.email,
      address: address ?? this.address,
      memo: memo ?? this.memo,
      imageUrl: imageUrl ?? this.imageUrl,
      visibility: visibility ?? this.visibility,
      isBlacklisted: isBlacklisted ?? this.isBlacklisted,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedByName: updatedByName ?? this.updatedByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      commentCount: commentCount ?? this.commentCount,
    );
  }
}

class BusinessCardComment {
  const BusinessCardComment({
    required this.id,
    required this.cardId,
    required this.body,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String cardId;
  final String body;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get edited => updatedAt.difference(createdAt).inSeconds.abs() > 2;

  factory BusinessCardComment.fromJson(Map<String, dynamic> json) {
    return BusinessCardComment(
      id: _str(json['id']),
      cardId: _str(json['card_id']),
      body: _str(json['body']),
      createdBy: _str(json['created_by']),
      createdByName: _str(json['created_by_name']),
      createdAt: _dt(json['created_at']),
      updatedAt: _dt(json['updated_at']),
    );
  }
}

class BusinessCardListResult {
  const BusinessCardListResult({
    required this.items,
    required this.hasMore,
  });

  final List<BusinessCard> items;
  final bool hasMore;
}

String _str(Object? v) => v?.toString().trim() ?? '';

bool _asBool(Object? v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v?.toString().trim().toLowerCase();
  return s == 'true' || s == 't' || s == '1';
}

int _asInt(Object? v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

DateTime _dt(Object? v) {
  final raw = v?.toString() ?? '';
  return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
}
