import 'package:flutter/material.dart';
import '../../services/exercise_engine.dart';

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

class ExerciseSessionScreen extends StatefulWidget {
  const ExerciseSessionScreen({super.key, this.questions = demoExerciseQuestions});
  final List<ExerciseQuestion> questions;
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

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  void _submit() {
    if (_grade != null || _index >= widget.questions.length) return;
    final question = widget.questions[_index];
    Object? response;
    if (question.type == ExerciseType.multipleChoice || question.type == ExerciseType.listeningChoice) {
      response = _selected;
    } else if (question.type == ExerciseType.matching) {
      response = Map<String, String>.from(_pairs);
    } else {
      response = _answer.text;
    }
    final grade = _engine.grade(question, response);
    setState(() {
      _grade = grade;
      if (grade.isCorrect == true) _correct++;
      if (!grade.isAutoGraded) _reviewRequired++;
    });
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
      _pairs.clear();
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
    final isChoice = q.type == ExerciseType.multipleChoice || q.type == ExerciseType.listeningChoice;
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
        if (isChoice) ...[
          if (q.type == ExerciseType.listeningChoice)
            Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('استخدم زر النطق في الدرس أو اقرأ الجملة بصوت مرتفع؛ يمكن إضافة تشغيل صوت مسجل لكل سؤال لاحقًا.'))),
              icon: const Icon(Icons.volume_up_rounded), label: const Text('تلميح الاستماع'),
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
          for (final pair in q.pairs)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
              Expanded(child: Text(pair.key, style: const TextStyle(fontWeight: FontWeight.w800))),
              const SizedBox(width: 10),
              Expanded(child: DropdownButtonFormField<String>(
                key: ValueKey('${q.id}-${pair.key}-$_index'),
                initialValue: _pairs[pair.key],
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                hint: const Text('اختر المعنى'),
                items: q.pairs.map((item) => DropdownMenuItem(value: item.value, child: Text(item.value))).toList(),
                onChanged: _grade == null ? (value) { if (value != null) setState(() => _pairs[pair.key] = value); } : null,
              )),
            ])),
        ] else ...[
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
    ExerciseType.fillBlank => 'فراغ',
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
