class Track {
  final String id;
  final String name;
  final String assetPath;

  const Track({
    required this.id,
    required this.name,
    required this.assetPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'assetPath': assetPath,
    };
  }

  factory Track.fromMap(Map<String, dynamic> map) {
    return Track(
      id: map['id'] as String,
      name: map['name'] as String,
      assetPath: map['assetPath'] as String,
    );
  }
}
