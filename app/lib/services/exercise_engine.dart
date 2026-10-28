import 'package:english_learning_legal_academy/services/learning_engine.dart';

enum ExerciseType {
  multipleChoice,
  matching,
  wordOrder,
  fillBlank,
  translation,
  listeningChoice,
  dictation,
  correction,
  dialogue,
  readingComprehension,
  sentenceWriting,
  speakingPrompt,
  courtScenario,
}

class ExerciseQuestion {
  const ExerciseQuestion({
    required this.id,
    required this.type,
    required this.prompt,
    this.acceptedAnswers = const <String>[],
    this.options = const <String>[],
    this.answerIndex,
    this.pairs = const <MapEntry<String, String>>[],
    this.explanation = '',
    this.hint = '',
    this.requiresHumanOrAIReview = false,
  });

  final String id;
  final ExerciseType type;
  final String prompt;
  final List<String> acceptedAnswers;
  final List<String> options;
  final int? answerIndex;
  final List<MapEntry<String, String>> pairs;
  final String explanation;
  final String hint;
  final bool requiresHumanOrAIReview;

  factory ExerciseQuestion.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] as String? ?? 'multiple_choice').toLowerCase();
    const types = <String, ExerciseType>{
      'multiple_choice': ExerciseType.multipleChoice,
      'matching': ExerciseType.matching,
      'word_order': ExerciseType.wordOrder,
      'fill_blank': ExerciseType.fillBlank,
      'translation': ExerciseType.translation,
      'listening_choice': ExerciseType.listeningChoice,
      'dictation': ExerciseType.dictation,
      'correction': ExerciseType.correction,
      'dialogue': ExerciseType.dialogue,
      'reading_comprehension': ExerciseType.readingComprehension,
      'sentence_writing': ExerciseType.sentenceWriting,
      'speaking_prompt': ExerciseType.speakingPrompt,
      'court_scenario': ExerciseType.courtScenario,
    };
    final type = types[rawType];
    if (type == null) throw FormatException('Unsupported exercise type: $rawType');
    final rawAnswers = json['accepted_answers'] ?? json['acceptedAnswers'];
    final answers = rawAnswers is List
        ? rawAnswers.map((value) => value.toString()).toList(growable: true)
        : <String>[];
    final singleAnswer = json['answer']?.toString();
    if (answers.isEmpty && singleAnswer != null && singleAnswer.isNotEmpty) answers.add(singleAnswer);
    final rawOptions = json['options'] as List<dynamic>? ?? const [];
    final rawPairs = json['pairs'] as List<dynamic>? ?? const [];
    final pairs = rawPairs.map((item) {
      final pair = Map<String, dynamic>.from(item as Map);
      return MapEntry(pair['left']?.toString() ?? '', pair['right']?.toString() ?? '');
    }).toList(growable: false);
    final rawIndex = json['answer_index'] ?? json['answerIndex'];
    return ExerciseQuestion(
      id: json['id']?.toString() ?? '',
      type: type,
      prompt: json['prompt']?.toString() ?? json['question']?.toString() ?? '',
      acceptedAnswers: answers,
      options: rawOptions.map((value) => value.toString()).toList(growable: false),
      answerIndex: rawIndex is int ? rawIndex : null,
      pairs: pairs,
      explanation: json['explanation']?.toString() ?? '',
      hint: json['hint']?.toString() ?? '',
      requiresHumanOrAIReview: type == ExerciseType.speakingPrompt || type == ExerciseType.courtScenario || type == ExerciseType.sentenceWriting,
    );
  }
}

class ExerciseGrade {
  const ExerciseGrade({required this.isCorrect, required this.isAutoGraded, required this.feedback});
  final bool? isCorrect;
  final bool isAutoGraded;
  final String feedback;
}

class ExerciseEngine {
  const ExerciseEngine();

  ExerciseGrade grade(ExerciseQuestion question, Object? response) {
    if (question.requiresHumanOrAIReview) {
      return const ExerciseGrade(
        isCorrect: null,
        isAutoGraded: false,
        feedback: 'يتطلب هذا التمرين معيار تقييم إضافيًا أو مراجعة من معلّم؛ لم تُخمن صحة الإجابة آليًا.',
      );
    }
    if (question.type == ExerciseType.matching) {
      if (response is! Map || question.pairs.isEmpty) return _wrong(question);
      final pairsCorrect = question.pairs.every((pair) =>
        response[pair.key] != null &&
        response[pair.key].toString().trim().toLowerCase() == pair.value.trim().toLowerCase());
      return pairsCorrect
          ? ExerciseGrade(isCorrect: true, isAutoGraded: true, feedback: question.explanation.isEmpty ? 'كل المطابقات صحيحة.' : question.explanation)
          : _wrong(question);
    }
    if (question.type == ExerciseType.multipleChoice || question.type == ExerciseType.listeningChoice) {
      if (response is! int || question.answerIndex == null) return _wrong(question);
      final correct = response == question.answerIndex;
      return correct
          ? ExerciseGrade(isCorrect: true, isAutoGraded: true, feedback: question.explanation.isEmpty ? 'إجابة صحيحة.' : question.explanation)
          : _wrong(question);
    }
    final accepted = question.acceptedAnswers;
    if (accepted.isEmpty || response == null) {
      return const ExerciseGrade(isCorrect: null, isAutoGraded: false, feedback: 'لم يُحدَّد نموذج إجابة كافٍ للتصحيح الآلي.');
    }
    final correct = LearningEngine.matchesAnswer(response.toString(), accepted);
    return correct
      ? ExerciseGrade(isCorrect: true, isAutoGraded: true, feedback: question.explanation.isEmpty ? 'إجابة صحيحة.' : question.explanation)
      : _wrong(question);
  }

  ExerciseGrade _wrong(ExerciseQuestion question) => ExerciseGrade(
    isCorrect: false,
    isAutoGraded: true,
    feedback: question.explanation.isEmpty ? 'ليست هذه الإجابة المتوقعة. راجع التعليمات وحاول مرة أخرى.' : question.explanation,
  );
}
