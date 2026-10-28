class Lesson {
  const Lesson({required this.id, required this.title, required this.level, required this.description, required this.contentVersion});
  final String id;
  final String title;
  final String level;
  final String description;
  final String contentVersion;

  factory Lesson.fromJson(Map<String, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Lesson field "$key" must be a non-empty string.');
      }
      return value;
    }
    return Lesson(id: requiredString('id'), title: requiredString('title'), level: requiredString('level'), description: requiredString('description'), contentVersion: requiredString('content_version'));
  }
}
