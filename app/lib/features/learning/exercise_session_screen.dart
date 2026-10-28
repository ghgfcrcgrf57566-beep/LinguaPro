import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../models/learning_lesson.dart';
import '../../services/exercise_engine.dart';
import '../../services/learning_engine.dart';
import '../../services/learning_store.dart';

const demoExerciseQuestions = <ExerciseQuestion>[
  ExerciseQuestion(id: 'demo-mcq', type: ExerciseType.multipleChoice, prompt: 'Choose the correct greeting.', options: ['Good morning.', 'Yesterday morning.', 'Morningly.'], answerIndex: 0, explanation: 'Good morning is a natural greeting.'),
  ExerciseQuestion(id: 'demo-match', type: ExerciseType.matching, prompt: 'Match each legal role to its Arabic meaning.', pairs: [MapEntry('judge', 'قاضٍ'), MapEntry('witness', 'شاهد'), MapEntry('lawyer', 'محامٍ')], explanation: 'These are common legal-role equivalents; exact titles may vary by jurisdiction.'),
  ExerciseQuestion(id: 'demo-order', type: ExerciseType.wordOrder, prompt: 'Arrange the words into a question: your / what / name / is', acceptedAnswers: ['What is your name'], explanation: 'Use question word + verb + subject/complement.'),
  ExerciseQuestion(id: 'demo-fill', type: ExerciseType.fillBlank, prompt: 'Complete: The witness ___ the question yesterday.', acceptedAnswers: ['answered'], explanation: 'Use the past form “answered” for a completed event yesterday.'),
  ExerciseQuestion(id: 'demo-translation', type: ExerciseType.translation, prompt: 'Translate into English: أحتاج إلى موعد.', acceptedAnswers: ['I need an appointment', 'I need to make an appointment'], explanation: 'Both sentences are natural translations.'),
  ExerciseQuestion(id: 'demo-listen', type: ExerciseType.listeningChoice, prompt: 'Listen to the spoken word, then select it.', options: ['court', 'course', 'coat'], answerIndex: 0, explanation: 'Listen for the final /t/ sound. The device TTS can read the prompt using the speaker button.'),
  ExerciseQuestion(id: 'demo-dictation', type: ExerciseType.dictation, prompt: 'Write the sentence you hear: The court is open.', acceptedAnswers: ['The court is open'], explanation: 'Check the article, noun, and adjective.'),
  ExerciseQuestion(id: 'demo-correction', type: ExerciseType.correction, prompt: 'Correct the sentence: She go to court every day.', acceptedAnswers: ['She goes to court every day'], explanation: 'With he/she/it in the present simple, add -s/-es to the verb.'),
  ExerciseQuestion(id: 'demo-dialogue', type: ExerciseType.dialogue, prompt: 'Complete the dialogue: “How can I help you?” — “___”', acceptedAnswers: ['I need legal advice', 'I would like legal advice', 'I need some legal advice'], explanation: 'Several polite responses are possible.'),
  ExerciseQuestion(id: 'demo-reading', type: ExerciseType.readingComprehension, prompt: 'Read: “The hearing was postponed until Monday.” What happened to the hearing?', acceptedAnswers: ['It was postponed until Monday', 'The hearing was postponed until Monday', 'It was delayed until Monday'], explanation: '“Postponed” means moved to a later time.'),
  ExerciseQuestion(id: 'demo-writing', type: ExerciseType.sentenceWriting, prompt: 'Write two sentences summarizing a routine appointment. Check grammar, clarity, and complete sentences.'),
  ExerciseQuestion(id: 'demo-speaking', type: ExerciseType.speakingPrompt, prompt: 'Speak aloud: introduce yourself and explain why you are visiting a law office.'),
  ExerciseQuestion(id: 'demo-court', type: ExerciseType.courtScenario, prompt: 'Courtroom role-play: ask a witness one neutral question about what they saw. Avoid suggesting the answer.'),
];

List<ExerciseQuestion> buildExercisesForLesson(LearningLesson lesson) {
  final result = <ExerciseQuestion>[];
  for (var i = 0; i < lesson.quiz.length; i++) {
    final q = lesson.quiz[i];
    result.add(ExerciseQuestion(
      id: '${lesson.id}-quiz-$i',
      type: ExerciseType.multipleChoice,
      prompt: q.question,
      options: q.options,
      answerIndex: q.answerIndex,
      explanation: q.explanation,
    ));
  }

  for (var i = 0; i < lesson.vocabulary.length; i++) {
    final word = lesson.vocabulary[i];
    result.add(ExerciseQuestion(
      id: '${lesson.id}-translate-$i',
      type: ExerciseType.translation,
      prompt: 'ترجم إلى الإنجليزية: ${word.meaning}',
      acceptedAnswers: [word.term],
      explanation: word.example.isEmpty ? 'تحقق من معنى المصطلح في سياق الدرس.' : 'مثال: ${word.example}',
    ));
    if (i < 2 && word.example.trim().isNotEmpty) {
      result.add(ExerciseQuestion(
        id: '${lesson.id}-dictation-$i',
        type: ExerciseType.dictation,
        prompt: 'استمع ثم اكتب الجملة كاملة.',
        acceptedAnswers: [word.example],
        spokenText: word.example,
        explanation: 'راجع ترتيب الكلمات والتهجئة وعلامات الترقيم.',
      ));
      final parts = word.example.trim().split(RegExp(r'\s+'));
      if (parts.length >= 3 && parts.length <= 9) {
        final shuffled = List<String>.from(parts)..shuffle();
        result.add(ExerciseQuestion(
          id: '${lesson.id}-order-$i',
          type: ExerciseType.wordOrder,
          prompt: 'رتب الكلمات لتكوين المثال الصحيح: ${shuffled.join(' / ')}',
          acceptedAnswers: [word.example],
          explanation: 'راجع المثال الأصلي في قسم المفردات.',
        ));
      }
      final escaped = RegExp(RegExp.escape(word.term), caseSensitive: false);
      if (escaped.hasMatch(word.example)) {
        result.add(ExerciseQuestion(
          id: '${lesson.id}-blank-$i',
          type: ExerciseType.fillBlank,
          prompt: word.example.replaceFirst(escaped, '_____'),
          acceptedAnswers: [word.term],
          explanation: 'الكلمة الناقصة: ${word.term}. ${word.meaning}',
        ));
      }
    }
  }

  if (lesson.vocabulary.length >= 2) {
    final pairs = lesson.vocabulary.take(5)
        .map((word) => MapEntry(word.term, word.meaning)).toList();
    result.add(ExerciseQuestion(
      id: '${lesson.id}-matching',
      type: ExerciseType.matching,
      prompt: 'طابق المصطلح الإنجليزي مع معناه العربي.',
      pairs: pairs,
      explanation: 'راجع المفردات ومعانيها في سياق الدرس.',
    ));
    final options = lesson.vocabulary.take(4).toList();
    for (var i = 0; i < options.length; i++) {
      result.add(ExerciseQuestion(
        id: '${lesson.id}-listen-$i',
        type: ExerciseType.listeningChoice,
        prompt: 'استمع إلى الكلمة المنطوقة واختر معناها.',
        options: options.map((word) => word.meaning).toList(),
        answerIndex: i,
        spokenText: options[i].term,
        explanation: '${options[i].term} تعني: ${options[i].meaning}',
      ));
    }
  }

  if (lesson.sections.isNotEmpty && lesson.quiz.isNotEmpty) {
    final section = lesson.sections.first;
    final q = lesson.quiz.first;
    result.add(ExerciseQuestion(
      id: '${lesson.id}-reading',
      type: ExerciseType.readingComprehension,
      prompt: 'اقرأ النص التالي ثم أجب:\n${section.body}\n\n${q.question}',
      options: q.options,
      answerIndex: q.answerIndex,
      explanation: q.explanation,
    ));
  }
  result.add(ExerciseQuestion(
    id: '${lesson.id}-dialogue',
    type: ExerciseType.dialogue,
    prompt: 'اكتب ردًا مهذبًا مناسبًا في حوار يتعلق بموضوع الدرس: ${lesson.title}.',
    requiresHumanOrAIReview: true,
    hint: 'استخدم عبارة واضحة ومناسبة للسياق، ثم راجعها مع المدرس.',
  ));
  result.add(ExerciseQuestion(
    id: '${lesson.id}-writing',
    type: ExerciseType.sentenceWriting,
    prompt: 'اكتب جملتين تستخدم فيهما مفردات هذا الدرس: ${lesson.title}.',
    requiresHumanOrAIReview: true,
    hint: 'راجع صحة القواعد ووضوح المعنى واستخدام المفردات.',
  ));
  result.add(ExerciseQuestion(
    id: '${lesson.id}-speaking',
    type: ExerciseType.speakingPrompt,
    prompt: lesson.isLegal
        ? 'تحدث بالإنجليزية واشرح فكرة الدرس لشخص يتلقى استشارة قانونية.'
        : 'تحدث بالإنجليزية ولخص ما تعلمته في درس: ${lesson.title}.',
    requiresHumanOrAIReview: true,
  ));
  if (lesson.isLegal) {
    result.add(ExerciseQuestion(
      id: '${lesson.id}-court',
      type: ExerciseType.courtScenario,
      prompt: 'سيناريو قضائي تعليمي مرتبط بموضوع "${lesson.title}": صغ سؤالًا محايدًا أو طلبًا مهنيًا مناسبًا.',
      requiresHumanOrAIReview: true,
      hint: 'تختلف المصطلحات والإجراءات بحسب النظام القانوني والاختصاص القضائي.',
    ));
  }
  return result;
}

class ExerciseSessionScreen extends StatefulWidget {
  const ExerciseSessionScreen({super.key, this.questions = demoExerciseQuestions, this.lessonId});
  final List<ExerciseQuestion> questions;
  final String? lessonId;
  @override
  State<ExerciseSessionScreen> createState() => _ExerciseSessionScreenState();
}

class _ExerciseSessionScreenState extends State<ExerciseSessionScreen> {
  final ExerciseEngine _engine = const ExerciseEngine();
  final TextEditingController _answer = TextEditingController();
  final Map<String, String> _pairs = <String, String>{};
  int _index = 0;
  int? _selected;
  ExerciseGrade? _grade;
  int _correct = 0;
  int _reviewRequired = 0;
  bool _submitting = false;
  bool _speaking = false;
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _listening = false;
  bool _speechAvailable = false;
  String _speechStatus = '';
  final List<String> _wordBank = <String>[];
  final List<String> _orderedWords = <String>[];
  final List<int> _usedWordIndices = <int>[];
  String? _selectedMatchKey;
  final int _sessionId = DateTime.now().microsecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    if (widget.questions.isNotEmpty) _prepareQuestion(0);
  }

  void _prepareQuestion(int index) {
    _wordBank.clear();
    _orderedWords.clear();
    _usedWordIndices.clear();
    _pairs.clear();
    _selectedMatchKey = null;
    if (index < 0 || index >= widget.questions.length) return;
    final question = widget.questions[index];
    if (question.type == ExerciseType.wordOrder && question.acceptedAnswers.isNotEmpty) {
      _wordBank.addAll(question.acceptedAnswers.first.trim().split(RegExp(r'\s+'))..shuffle());
    }
  }

  @override
  void dispose() {
    _answer.dispose();
    _tts.stop();
    _speech.stop();
    super.dispose();
  }

  Future<void> _recordReviewProgress(
    ExerciseQuestion question,
    Object? response,
    ExerciseGrade grade,
    String eventId,
  ) async {
    final lessonId = widget.lessonId;
    if (lessonId == null || grade.isCorrect == null) return;
    final correct = grade.isCorrect == true;

    if (question.type == ExerciseType.translation && question.acceptedAnswers.isNotEmpty) {
      final promptParts = question.prompt.split(':');
      final meaning = promptParts.length > 1 ? promptParts.skip(1).join(':').trim() : question.prompt;
      await LearningStore.instance.recordWord(
        lessonId: lessonId,
        term: question.acceptedAnswers.first,
        meaning: meaning,
        correct: correct,
        eventId: '$eventId:review:${question.acceptedAnswers.first.toLowerCase()}',
      );
      return;
    }

    if (question.type == ExerciseType.listeningChoice &&
        question.spokenText.isNotEmpty &&
        question.answerIndex != null &&
        question.answerIndex! >= 0 &&
        question.answerIndex! < question.options.length) {
      await LearningStore.instance.recordWord(
        lessonId: lessonId,
        term: question.spokenText,
        meaning: question.options[question.answerIndex!],
        correct: correct,
        eventId: '$eventId:review:${question.spokenText.toLowerCase()}',
      );
      return;
    }

    if (question.type == ExerciseType.matching && response is Map) {
      for (final pair in question.pairs) {
        final pairCorrect = response[pair.key]?.toString().trim().toLowerCase() ==
            pair.value.trim().toLowerCase();
        await LearningStore.instance.recordWord(
          lessonId: lessonId,
          term: pair.key,
          meaning: pair.value,
          correct: pairCorrect,
          eventId: '$eventId:review:${pair.key.toLowerCase()}',
        );
      }
    }
  }
  Future<void> _submit() async {
    if (_grade != null || _submitting || _index >= widget.questions.length) return;
    _submitting = true;
    final question = widget.questions[_index];
    Object? response;
    if (question.type == ExerciseType.multipleChoice || question.type == ExerciseType.listeningChoice) {
      response = _selected;
    } else if (question.type == ExerciseType.matching) {
      response = Map<String, String>.from(_pairs);
    } else if (question.type == ExerciseType.wordOrder) {
      response = _orderedWords.join(' ');
    } else if (question.type == ExerciseType.fillBlank && question.options.isNotEmpty) {
      response = _selected;
    } else {
      response = _answer.text;
    }
    if (response is String && response.trim().isEmpty) {
      _submitting = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أدخل إجابتك قبل المتابعة.')),
        );
      }
      return;
    }
    if ((question.type == ExerciseType.multipleChoice || question.type == ExerciseType.listeningChoice ||
        (question.type == ExerciseType.fillBlank && question.options.isNotEmpty)) &&
        (response is! int || response < 0 || response >= question.options.length)) {
      _submitting = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اختر إجابة أولًا.')),
        );
      }
      return;
    }
    if (question.type == ExerciseType.wordOrder && _orderedWords.isEmpty) {
      _submitting = false;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر الكلمات ورتبها أولًا.')));
      return;
    }
    if (question.type == ExerciseType.matching &&
        question.pairs.any((pair) => (_pairs[pair.key] ?? '').trim().isEmpty)) {
      _submitting = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أكمل مطابقة جميع العناصر أولًا.')),
        );
      }
      return;
    }
    final eventId = 'exercise-session:$_sessionId:${question.id}';
    final allowed = await LearningEngine.instance.consumeAttempt(eventId);
    if (!allowed) {
      _submitting = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('انتهت محاولاتك اليومية. يمكنك تعديلها من خريطة التعلم.')));
      }
      return;
    }
    final grade = _engine.grade(question, response);
    if (grade.isAutoGraded && grade.isCorrect != null) {
      final chosen = response is int && response >= 0 && response < question.options.length
          ? question.options[response] : response?.toString() ?? '';
      await LearningEngine.instance.recordAnswer(
        eventId: eventId,
        lessonId: widget.lessonId ?? question.id.split('-').first,
        prompt: question.prompt,
        answer: chosen,
        correct: grade.isCorrect == true,
        targetTerm: question.answerIndex != null && question.answerIndex! < question.options.length
            ? question.options[question.answerIndex!] : (question.acceptedAnswers.isNotEmpty ? question.acceptedAnswers.first : null),
        targetMeaning: question.explanation,
      );
      await _recordReviewProgress(question, response, grade, eventId);
      if (grade.isCorrect == true) {
        await LearningEngine.instance.awardXp(eventId: 'exercise-correct:$_sessionId:${question.id}', points: 1);
      }
    }
    _submitting = false;
    if (!mounted) return;
    setState(() {
      _grade = grade;
      if (grade.isCorrect == true) {
        _correct++;
      }
      if (!grade.isAutoGraded) {
        _reviewRequired++;
      }
    });
  }

  Future<void> _startListening() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) { if (mounted) setState(() { _speechStatus = status; _listening = status == 'listening'; }); },
        onError: (error) { if (mounted) setState(() { _speechStatus = error.errorMsg; _listening = false; }); },
      );
      if (!_speechAvailable) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('التعرف على الكلام غير متاح. تحقق من إذن الميكروفون وخدمة التعرف على الكلام في الجهاز.')));
        return;
      }
      if (mounted) setState(() { _listening = true; _speechStatus = 'listening'; });
      await _speech.listen(
        localeId: 'en_US',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _answer.text = result.recognizedWords;
            _answer.selection = TextSelection.collapsed(offset: _answer.text.length);
            if (result.finalResult) _listening = false;
          });
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _listening = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر بدء التعرف على الكلام. يمكنك كتابة إجابتك يدويًا.')));
      }
    }
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty || _speaking) return;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.42);
      setState(() => _speaking = true);
      await _tts.speak(text);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تشغيل النطق على هذا الجهاز.')));
      }
    } finally {
      if (mounted) {
        setState(() => _speaking = false);
      }
    }
  }

  void _next() {
    if (_index + 1 >= widget.questions.length) {
      setState(() => _index = widget.questions.length);
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _grade = null;
      _answer.clear();
      _prepareQuestion(_index);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_index >= widget.questions.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('ملخص التمارين')),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.emoji_events_rounded, size: 58, color: Color(0xFFE6AD31)),
            const SizedBox(height: 12),
            const Text('أكملت مجموعة التمارين', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('إجابات صحيحة: $_correct من ${widget.questions.length - _reviewRequired} تمارين قابلة للتصحيح الآلي'),
            Text('تحتاج إلى مراجعة ذاتية أو معيار تقييم: $_reviewRequired'),
            const SizedBox(height: 18),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('العودة إلى خريطة التعلّم')),
          ]),
        )),
      );
    }
    final q = widget.questions[_index];
    final isChoice = q.type == ExerciseType.multipleChoice || q.type == ExerciseType.listeningChoice ||
        (q.type == ExerciseType.fillBlank && q.options.isNotEmpty);
    return Scaffold(
      appBar: AppBar(title: const Text('تمارين LinguaPro المتنوعة')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        LinearProgressIndicator(value: (_index + 1) / widget.questions.length, minHeight: 7, borderRadius: BorderRadius.circular(7)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Text('تمرين ${_index + 1} من ${widget.questions.length}', style: const TextStyle(color: Color(0xFF718078), fontWeight: FontWeight.w700))),
          Chip(label: Text(_typeLabel(q.type))),
        ]),
        const SizedBox(height: 12),
        Text(q.prompt, style: const TextStyle(fontSize: 21, height: 1.6, fontWeight: FontWeight.w900)),
        const SizedBox(height: 18),
        if (q.type == ExerciseType.dictation && q.spokenText.isNotEmpty)
          Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(
            onPressed: _speaking ? null : () => _speak(q.spokenText),
            icon: const Icon(Icons.volume_up_rounded),
            label: const Text('استمع إلى الجملة ثم اكتبها'),
          )),
        if (isChoice) ...[
          if (q.spokenText.isNotEmpty)
            Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(
              onPressed: _speaking ? null : () => _speak(q.spokenText),
              icon: const Icon(Icons.volume_up_rounded),
              label: Text(q.type == ExerciseType.listeningChoice ? 'استمع إلى الكلمة' : 'استمع إلى الجملة'),
            )),
          for (var i = 0; i < q.options.length; i++)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: OutlinedButton(
              onPressed: _grade == null ? () => setState(() => _selected = i) : null,
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.all(14),
                backgroundColor: _grade == null && _selected == i ? const Color(0xFFE1F2E8) : null,
                side: BorderSide(color: _grade != null && i == q.answerIndex ? Colors.green : _selected == i ? const Color(0xFF1D9B69) : const Color(0xFFDDE5DF)),
              ),
              child: Text(q.options[i]),
            )),
        ] else if (q.type == ExerciseType.matching) ...[
          const Text('اضغط على المصطلح ثم اضغط على معناه لإتمام المطابقة.', style: TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          for (final pair in q.pairs)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: InkWell(
              onTap: _grade == null ? () => setState(() => _selectedMatchKey = pair.key) : null,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _selectedMatchKey == pair.key ? const Color(0xFF58CC02) : const Color(0xFFD8E1E8), width: _selectedMatchKey == pair.key ? 2 : 1),
                  color: _pairs.containsKey(pair.key) ? const Color(0xFFE8F8DF) : Colors.white,
                ),
                child: Row(children: [Expanded(child: Text(pair.key, style: const TextStyle(fontWeight: FontWeight.w800))), const Icon(Icons.touch_app_rounded, color: Color(0xFF7A8A99))]),
              ),
            )),
          const Divider(height: 22),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final pair in q.pairs)
              ChoiceChip(
                label: Text(pair.value),
                selected: _pairs.values.contains(pair.value),
                onSelected: _grade != null || _selectedMatchKey == null ? null : (_) => setState(() {
                  _pairs.removeWhere((key, value) => value == pair.value);
                  _pairs[_selectedMatchKey!] = pair.value;
                  _selectedMatchKey = null;
                }),
              ),
          ]),
          if (_pairs.isNotEmpty) Text('تمت مطابقة ${_pairs.length} من ${q.pairs.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
        ] else if (q.type == ExerciseType.wordOrder) ...[
          const Text('اضغط الكلمات بالترتيب لتكوين الجملة.', style: TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(minHeight: 66),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF0F8E9), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFB9DCA4))),
            child: Wrap(spacing: 7, runSpacing: 7, children: [
              for (var i = 0; i < _orderedWords.length; i++)
                ActionChip(label: Text(_orderedWords[i]), onPressed: _grade == null ? () => setState(() {
                  _orderedWords.removeAt(i);
                  _usedWordIndices.removeAt(i);
                }) : null),
            ]),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < _wordBank.length; i++)
              if (!_usedWordIndices.contains(i))
                ActionChip(label: Text(_wordBank[i]), onPressed: _grade == null ? () => setState(() { _usedWordIndices.add(i); _orderedWords.add(_wordBank[i]); }) : null),
          ]),
          TextButton.icon(onPressed: _grade == null ? () => setState(() { _orderedWords.clear(); _usedWordIndices.clear(); }) : null, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة الترتيب')),
        ] else ...[
          if (q.type == ExerciseType.speakingPrompt || q.type == ExerciseType.courtScenario)
            Align(alignment: Alignment.centerRight, child: FilledButton.tonalIcon(
              onPressed: _grade == null ? _startListening : null,
              icon: Icon(_listening ? Icons.stop_circle_rounded : Icons.mic_rounded),
              label: Text(_listening ? 'إيقاف التسجيل' : 'تحدث بالإنجليزية'),
            )),
          if (_speechStatus.isNotEmpty && (q.type == ExerciseType.speakingPrompt || q.type == ExerciseType.courtScenario))
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(_listening ? 'يستمع الآن… تحدث بوضوح.' : 'النص الذي تعرّف عليه الجهاز يظهر أدناه. هذا تفريغ للكلام وليس درجة نطق صوتية دقيقة.', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
          TextField(
            controller: _answer,
            enabled: _grade == null,
            minLines: q.type == ExerciseType.sentenceWriting || q.type == ExerciseType.speakingPrompt || q.type == ExerciseType.courtScenario ? 3 : 1,
            maxLines: q.type == ExerciseType.sentenceWriting || q.type == ExerciseType.speakingPrompt || q.type == ExerciseType.courtScenario ? 5 : 2,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: q.type == ExerciseType.speakingPrompt ? 'تحدث ثم دوّن ما قلته (اختياري)…' : q.type == ExerciseType.courtScenario ? 'اكتب سؤالك للمحكمة الافتراضية…' : 'اكتب إجابتك هنا…',
            ),
          ),
        ],
        if (_grade != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _grade!.isCorrect == true ? const Color(0xFFE4F5E9) : _grade!.isCorrect == false ? const Color(0xFFFFF0E6) : const Color(0xFFEAF0FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(_grade!.feedback, style: const TextStyle(height: 1.7)),
          ),
          if (q.hint.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('تلميح: ${q.hint}')),
        ],
        const SizedBox(height: 18),
        if (_grade == null)
          FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.check_rounded), label: const Text('تحقق من الإجابة'))
        else
          FilledButton(onPressed: _next, child: Text(_index == widget.questions.length - 1 ? 'عرض الملخص' : 'التمرين التالي')),
      ]),
    );
  }

  String _typeLabel(ExerciseType type) => switch (type) {
    ExerciseType.multipleChoice => 'اختيار',
    ExerciseType.matching => 'مطابقة',
    ExerciseType.wordOrder => 'ترتيب',
    ExerciseType.fillBlank => 'أكمل الجملة',
    ExerciseType.translation => 'ترجمة',
    ExerciseType.listeningChoice => 'استماع',
    ExerciseType.dictation => 'إملاء',
    ExerciseType.correction => 'تصحيح',
    ExerciseType.dialogue => 'حوار',
    ExerciseType.readingComprehension => 'فهم مقروء',
    ExerciseType.sentenceWriting => 'كتابة',
    ExerciseType.speakingPrompt => 'محادثة',
    ExerciseType.courtScenario => 'سيناريو قضائي',
  };
}
