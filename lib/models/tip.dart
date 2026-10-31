class TipGroup {
  final String id;
  final String name;
  const TipGroup({required this.id, required this.name});

  factory TipGroup.fromJson(Map<String, dynamic> json) => TipGroup(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}

class KitchenTip {
  final String id;
  final String title;
  final String groupId;
  final String groupName;
  final String path;
  final String summary;
  final String markdown;

  const KitchenTip({
    required this.id,
    required this.title,
    required this.groupId,
    required this.groupName,
    required this.path,
    required this.summary,
    required this.markdown,
  });

  factory KitchenTip.fromJson(Map<String, dynamic> json) => KitchenTip(
        id: json['id'] as String,
        title: json['title'] as String,
        groupId: json['groupId'] as String? ?? 'general',
        groupName: json['groupName'] as String? ?? '厨房常识',
        path: json['path'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        markdown: json['markdown'] as String? ?? '',
      );
}

class TipsDatabase {
  final String source;
  final String attribution;
  final List<TipGroup> groups;
  final List<KitchenTip> tips;

  const TipsDatabase({
    required this.source,
    required this.attribution,
    required this.groups,
    required this.tips,
  });

  factory TipsDatabase.fromJson(Map<String, dynamic> json) => TipsDatabase(
        source: json['source'] as String? ?? '',
        attribution: json['attribution'] as String? ?? '',
        groups: (json['groups'] as List<dynamic>? ?? const [])
            .map((e) => TipGroup.fromJson(e as Map<String, dynamic>))
            .toList(),
        tips: (json['tips'] as List<dynamic>? ?? const [])
            .map((e) => KitchenTip.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
