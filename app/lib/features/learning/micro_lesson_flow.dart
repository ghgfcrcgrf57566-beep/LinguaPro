import 'dart:math' as math;

import '../../models/learning_lesson.dart';

enum MicroStepType {
  presentation,
  imageChoice,
  audioChoice,
  wordBank,
  fillBlank,
  speakingPractice,
  hardChallenge,
}

class MicroLessonStep {
  const MicroLessonStep({
    required this.id,
    required this.type,
    required this.prompt,
    this.word,
    this.options = const <String>[],
    this.answerIndex,
    this.acceptedAnswers = const <String>[],
    this.spokenText = '',
    this.example = '',
    this.explanation = '',
  });

  final String id;
  final MicroStepType type;
  final String prompt;
  final LearningWord? word;
  final List<String> options;
  final int? answerIndex;
  final List<String> acceptedAnswers;
  final String spokenText;
  final String example;
  final String explanation;

  bool get isPresentation => type == MicroStepType.presentation;
  bool get isSelfAssessed => type == MicroStepType.speakingPractice;
  bool get isChoice => type == MicroStepType.imageChoice ||
      type == MicroStepType.audioChoice ||
      type == MicroStepType.fillBlank ||
      type == MicroStepType.hardChallenge;
  bool get isAutoGraded => isChoice || type == MicroStepType.wordBank;
}

class MicroLessonFlow {
  const MicroLessonFlow._();

  /// Builds a short, deterministic lesson from the actual local lesson content.
  /// The flow has eight main screens; mistake review and celebration are
  /// session states, not duplicated content screens.
  static List<MicroLessonStep> build(LearningLesson lesson) {
    if (lesson.vocabulary.isEmpty) {
      throw ArgumentError.value(lesson.id, 'lesson', 'A micro-lesson needs at least one vocabulary item.');
    }
    final words = lesson.vocabulary;
    final first = words.first;
    final second = words.length > 1 ? words[1] : words.first;
    final choices = _choiceWords(words, first);
    final secondChoices = _choiceWords(words, second);
    final firstExample = _exampleFor(first);
    final secondExample = _exampleFor(second);
    final challengeQuestion = lesson.quiz.isNotEmpty ? lesson.quiz.first : null;

    return <MicroLessonStep>[
      MicroLessonStep(
        id: '${lesson.id}-present-1',
        type: MicroStepType.presentation,
        prompt: 'تعرّف على الكلمة الأولى',
        word: first,
        example: firstExample,
        spokenText: first.term,
        explanation: first.meaning,
      ),
      MicroLessonStep(
        id: '${lesson.id}-visual-1',
        type: MicroStepType.imageChoice,
        prompt: 'اختر المعنى الصحيح للكلمة: ${first.term}',
        word: first,
        options: choices.map((word) => word.meaning).toList(growable: false),
        answerIndex: choices.indexOf(first),
        explanation: '${first.term} تعني: ${first.meaning}',
      ),
      MicroLessonStep(
        id: '${lesson.id}-audio-1',
        type: MicroStepType.audioChoice,
        prompt: 'استمع إلى النطق واختر الكلمة التي سمعتها.',
        word: first,
        options: choices.map((word) => word.term).toList(growable: false),
        answerIndex: choices.indexOf(first),
        spokenText: first.term,
        explanation: 'الكلمة المنطوقة هي ${first.term}، ومعناها ${first.meaning}.',
      ),
      MicroLessonStep(
        id: '${lesson.id}-word-bank',
        type: MicroStepType.wordBank,
        prompt: 'رتّب الكلمات لتكوين الجملة الإنجليزية.',
        word: first,
        options: _wordBankOptions(firstExample, lesson.id),
        acceptedAnswers: <String>[firstExample],
        example: firstExample,
        explanation: 'الجملة الصحيحة: $firstExample',
      ),
      MicroLessonStep(
        id: '${lesson.id}-present-2',
        type: MicroStepType.presentation,
        prompt: 'تعرّف على كلمة أخرى',
        word: second,
        example: secondExample,
        spokenText: second.term,
        explanation: second.meaning,
      ),
      MicroLessonStep(
        id: '${lesson.id}-fill-blank',
        type: MicroStepType.fillBlank,
        prompt: _blankPrompt(second, secondExample),
        word: second,
        options: secondChoices.map((word) => word.term).toList(growable: false),
        answerIndex: secondChoices.indexOf(second),
        example: secondExample,
        explanation: 'الإجابة الصحيحة: ${second.term} — ${second.meaning}.',
      ),
      MicroLessonStep(
        id: '${lesson.id}-speaking',
        type: MicroStepType.speakingPractice,
        prompt: 'استمع إلى المثال، ثم تدرب على نطقه بصوت واضح.',
        word: second,
        spokenText: secondExample,
        example: secondExample,
        explanation: 'التدرب على النطق ذاتي التقييم؛ لا يدّعي التطبيق أنه حلّل صوتك.',
      ),
      MicroLessonStep(
        id: '${lesson.id}-challenge',
        type: MicroStepType.hardChallenge,
        prompt: challengeQuestion?.question ?? 'اختر المعنى الصحيح للكلمة الثانية: ${second.term}',
        word: second,
        options: challengeQuestion?.options ?? secondChoices.map((word) => word.meaning).toList(growable: false),
        answerIndex: challengeQuestion?.answerIndex ?? secondChoices.indexOf(second),
        explanation: challengeQuestion?.explanation ?? '${second.term} تعني: ${second.meaning}.',
      ),
    ];
  }

  static String _exampleFor(LearningWord word) {
    final example = word.example.trim();
    if (example.isNotEmpty) return example;
    return 'I am learning ${word.term}.';
  }

  static String _blankPrompt(LearningWord word, String example) {
    final escaped = RegExp(RegExp.escape(word.term), caseSensitive: false);
    if (escaped.hasMatch(example)) return example.replaceFirst(escaped, '_____');
    return 'أكمل الجملة باختيار الكلمة المناسبة: “${word.term}”';
  }

  static List<LearningWord> _choiceWords(List<LearningWord> words, LearningWord target) {
    final result = <LearningWord>[target];
    for (final word in words) {
      if (word.term.toLowerCase() == target.term.toLowerCase()) continue;
      if (!result.any((item) => item.term.toLowerCase() == word.term.toLowerCase())) {
        result.add(word);
      }
      if (result.length == 4) break;
    }
    // Lessons with fewer than four vocabulary items still get four distinct
    // distractors, without fabricating vocabulary that is not in the lesson.
    final fallbacks = <LearningWord>[
      const LearningWord(term: 'office', meaning: 'مكتب', example: 'I work in an office.'),
      const LearningWord(term: 'meeting', meaning: 'اجتماع', example: 'The meeting starts now.'),
      const LearningWord(term: 'document', meaning: 'مستند', example: 'Please read the document.'),
      const LearningWord(term: 'appointment', meaning: 'موعد', example: 'I have an appointment.'),
    ];
    for (final fallback in fallbacks) {
      if (result.length == 4) break;
      if (!result.any((item) => item.term.toLowerCase() == fallback.term.toLowerCase())) {
        result.add(fallback);
      }
    }
    return result;
  }

  static List<String> _wordBankOptions(String sentence, String seed) {
    final tokens = sentence.trim().split(RegExp(r'\s+'));
    final options = List<String>.from(tokens);
    if (options.length < 7) {
      for (final distractor in const <String>['please', 'today', 'quickly']) {
        if (options.length >= 7) break;
        if (!options.any((token) => token.toLowerCase() == distractor)) options.add(distractor);
      }
    }
    // Deterministic shuffle keeps tests and repeated sessions predictable.
    final random = math.Random(seed.codeUnits.fold<int>(0, (sum, unit) => sum + unit));
    for (var i = options.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = options[i];
      options[i] = options[j];
      options[j] = temp;
    }
    if (options.join(' ') == sentence.trim() && options.length > 1) {
      final first = options.removeAt(0);
      options.add(first);
    }
    return options;
  }
}
