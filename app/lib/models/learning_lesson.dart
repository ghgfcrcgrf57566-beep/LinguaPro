class LearningWord {
  const LearningWord({
    required this.term,
    required this.meaning,
    required this.example,
    this.pronunciation = '',
  });

  final String term;
  final String meaning;
  final String example;
  final String pronunciation;

  factory LearningWord.fromJson(Map<String, dynamic> json) => LearningWord(
        term: json['term'] as String? ?? '',
        meaning: json['meaning'] as String? ?? '',
        example: json['example'] as String? ?? '',
        pronunciation: json['pronunciation'] as String? ?? '',
      );
}

class LessonQuestion {
  const LessonQuestion({
    required this.question,
    required this.options,
    required this.answerIndex,
    required this.explanation,
  });

  final String question;
  final List<String> options;
  final int answerIndex;
  final String explanation;

  factory LessonQuestion.fromJson(Map<String, dynamic> json) {
    final options = (json['options'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false);
    final rawIndex = json['answer_index'];
    final answerIndex = rawIndex is int ? rawIndex : 0;
    if (options.isEmpty || answerIndex < 0 || answerIndex >= options.length) {
      throw FormatException('Invalid answer_index in question: ${json['question']}');
    }
    return LessonQuestion(
      question: json['question'] as String? ?? '',
      options: options,
      answerIndex: answerIndex,
      explanation: json['explanation'] as String? ?? '',
    );
  }
}

class LearningSection {
  const LearningSection({required this.heading, required this.body});

  final String heading;
  final String body;

  factory LearningSection.fromJson(Map<String, dynamic> json) => LearningSection(
        heading: json['heading'] as String? ?? '',
        body: json['body'] as String? ?? '',
      );
}

class LearningLesson {
  const LearningLesson({
    required this.id,
    required this.title,
    required this.level,
    required this.track,
    required this.description,
    required this.objectives,
    required this.vocabulary,
    required this.sections,
    required this.quiz,
  });

  final String id;
  final String title;
  final String level;
  final String track;
  final String description;
  final List<String> objectives;
  final List<LearningWord> vocabulary;
  final List<LearningSection> sections;
  final List<LessonQuestion> quiz;

  bool get isLegal => track == 'legal-english';

  factory LearningLesson.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(String key, T Function(Map<String, dynamic>) parser) =>
        (json[key] as List<dynamic>? ?? const [])
            .map((item) => parser(Map<String, dynamic>.from(item as Map)))
            .toList(growable: false);

    return LearningLesson(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      level: json['level'] as String? ?? 'A1',
      track: json['track'] as String? ?? 'general-english',
      description: json['description'] as String? ?? '',
      objectives: (json['objectives'] as List<dynamic>? ?? const [])
          .map((item) => item.toString()).toList(growable: false),
      vocabulary: parseList('vocabulary', LearningWord.fromJson),
      sections: parseList('sections', LearningSection.fromJson),
      quiz: parseList('quiz', LessonQuestion.fromJson),
    );
  }
}
