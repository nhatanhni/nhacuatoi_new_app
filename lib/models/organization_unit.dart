class OrganizationUnit {
  final String id;
  final String name;
  final String code;
  final int type;
  final String? parentId;

  const OrganizationUnit({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    this.parentId,
  });

  factory OrganizationUnit.fromJson(Map<String, dynamic> json) {
    return OrganizationUnit(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
      code: json['Code']?.toString() ?? '',
      type: (json['Type'] as num?)?.toInt() ?? 0,
      parentId: json['ParentId']?.toString(),
    );
  }
}
