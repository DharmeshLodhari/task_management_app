class Recording {
  final String id;
  final String filePath;
  final String name;
  final DateTime createdAt;

  const Recording({
    required this.id,
    required this.filePath,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'filePath': filePath,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Recording.fromJson(Map<String, dynamic> json) => Recording(
        id: json['id'] as String,
        filePath: json['filePath'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
