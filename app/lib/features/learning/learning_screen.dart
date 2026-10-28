import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../models/learning_lesson.dart';
import '../../services/learning_store.dart';

enum LearningMode { general, legal, review }

class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key, this.mode = LearningMode.general});

  final LearningMode mode;

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  late Future<List<LearningLesson>> _lessonsFuture;

  @override
  void initState() {
    super.initState();
    _lessonsFuture = _loadLessons();
  }

  Future<List<LearningLesson>> _loadLessons() async {
    final paths = <String>[
      if (widget.mode != LearningMode.legal) 'assets/lessons/english_a1.json',
      if (widget.mode != LearningMode.general) 'assets/lessons/legal_english.json',
    ];
    final lessons = <LearningLesson>[];
    for (final path in paths) {
      final text = await rootBundle.loadString(path);
      final json = jsonDecode(text) as Map<String, dynamic>;
      final list = json['lessons'] as List<dynamic>? ?? const [];
      lessons.addAll(list.map((item) =>
          LearningLesson.fromJson(Map<String, dynamic>.from(item as Map))));
    }
    return lessons;
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.mode) {
      LearningMode.general => 'مسار الإنجليزية',
      LearningMode.legal => 'أكاديمية الإنجليزية القانونية',
      LearningMode.review => 'مركز المراجعة الذكية',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<List<LearningLesson>>(
        future: _lessonsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('تعذر تحميل الدروس المحلية: ${snapshot.error}', textAlign: TextAlign.center),
            ));
          }
          final lessons = snapshot.data ?? const <LearningLesson>[];
          if (widget.mode == LearningMode.review) {
            return _ReviewList(lessons: lessons);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF172544), Color(0xFF334C82)],
                  ),
                ),
                child: Text(
                  widget.mode == LearningMode.legal
                      ? 'مصطلحات العقود والمحاكم والإجراءات، مع أمثلة وترجمات تراعي السياق القانوني.'
                      : 'تعلّم قصير، استرجاع نشط، واختبارات تساعدك على تذكر الكلمات مع مرور الوقت.',
                  style: const TextStyle(color: Colors.white, height: 1.8, fontSize: 15),
                ),
              ),
              const SizedBox(height: 16),
              for (final lesson in lessons)
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    leading: CircleAvatar(
                      backgroundColor: lesson.isLegal ? const Color(0xFFFFF0D3) : const Color(0xFFEAF0FF),
                      child: Icon(lesson.isLegal ? Icons.gavel_rounded : Icons.menu_book_rounded,
                          color: const Color(0xFF4059A7)),
                    ),
                    title: Text(lesson.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('${lesson.description}\n${lesson.vocabulary.length} مفردات · ${lesson.quiz.length} أسئلة'),
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => LessonScreen(lesson: lesson),
                    )),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.lesson});
  final LearningLesson lesson;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  int _tab = 0;
  int _wordIndex = 0;
  int _questionIndex = 0;
  int? _selected;
  bool _answered = false;
  int _score = 0;
  bool _finished = false;

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    return Scaffold(
      appBar: AppBar(title: Text(lesson.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: _finished ? _completion() : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              _ModeChip(label: 'المفردات', selected: _tab == 0, onTap: () => setState(() => _tab = 0)),
              const SizedBox(width: 8),
              _ModeChip(label: 'الشرح', selected: _tab == 1, onTap: () => setState(() => _tab = 1)),
              const SizedBox(width: 8),
              _ModeChip(label: 'الاختبار', selected: _tab == 2, onTap: () => setState(() => _tab = 2)),
            ]),
          ),
          Expanded(child: IndexedStack(
            index: _tab,
            children: [_vocabulary(), _sections(), _quiz()],
          )),
        ],
      ),
    );
  }

  Widget _vocabulary() {
    final words = widget.lesson.vocabulary;
    if (words.isEmpty) return const Center(child: Text('لا توجد مفردات في هذا الدرس.'));
    final word = words[_wordIndex.clamp(0, words.length - 1)];
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        LinearProgressIndicator(value: (_wordIndex + 1) / words.length, minHeight: 6, borderRadius: BorderRadius.circular(6)),
        const SizedBox(height: 18),
        Text('الكلمة ${_wordIndex + 1} من ${words.length}', style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 12),
        Card(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Text(word.term, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF263E81))),
            if (word.pronunciation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('مساعدة للنطق: ${word.pronunciation}', style: const TextStyle(color: Colors.grey)),
            ],
            const SizedBox(height: 14),
            Text(word.meaning, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const Divider(height: 30),
            Text(word.example, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
          ]),
        )),
        const SizedBox(height: 16),
        const Text('حاول أن تقول المعنى من ذاكرتك قبل إظهاره، ثم استخدم الكلمة في جملة من إنشائك.', style: TextStyle(height: 1.8)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: _wordIndex == 0 ? null : () => setState(() => _wordIndex--),
            child: const Text('السابقة'),
          )),
          const SizedBox(width: 12),
          Expanded(child: FilledButton(
            onPressed: _wordIndex >= words.length - 1
                ? () => setState(() => _tab = 2)
                : () => setState(() => _wordIndex++),
            child: Text(_wordIndex >= words.length - 1 ? 'ابدأ الاختبار' : 'الكلمة التالية'),
          )),
        ]),
      ],
    );
  }

  Widget _sections() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      for (final section in widget.lesson.sections)
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(section.heading, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            SelectableText(section.body, style: const TextStyle(height: 1.9, fontSize: 15)),
          ]),
        )),
      if (widget.lesson.isLegal)
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('تنبيه: المحتوى للتعليم اللغوي، ولا يُعد رأيًا أو استشارة قانونية بشأن واقعة محددة.', style: TextStyle(color: Colors.grey, height: 1.7)),
        ),
    ],
  );

  Widget _quiz() {
    final questions = widget.lesson.quiz;
    if (questions.isEmpty) return const Center(child: Text('لا توجد أسئلة لهذا الدرس.'));
    if (_questionIndex >= questions.length) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.emoji_events_rounded, size: 52, color: Color(0xFFE0A92E)),
          const SizedBox(height: 12),
          Text('نتيجتك: $_score من ${questions.length}', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          FilledButton(onPressed: _resetQuiz, child: const Text('إعادة الاختبار')),
          TextButton(onPressed: _completeLesson, child: const Text('إنهاء الدرس وحفظ التقدم')),
        ]),
      ));
    }
    final question = questions[_questionIndex];
    return ListView(padding: const EdgeInsets.all(18), children: [
      LinearProgressIndicator(value: (_questionIndex + 1) / questions.length, minHeight: 6),
      const SizedBox(height: 20),
      Text('السؤال ${_questionIndex + 1} من ${questions.length}', style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 12),
      Text(question.question, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, height: 1.6)),
      const SizedBox(height: 18),
      for (var i = 0; i < question.options.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.all(15),
              side: BorderSide(color: _answered && i == question.answerIndex ? Colors.green : const Color(0xFFDDE3EF)),
              backgroundColor: _answered && i == question.answerIndex ? const Color(0xFFE7F7EC) : null,
            ),
            onPressed: _answered ? null : () => _answer(i),
            child: Text(question.options[i], style: const TextStyle(fontSize: 15)),
          ),
        ),
      if (_answered) Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFEAF0FF), borderRadius: BorderRadius.circular(12)),
        child: Text(question.explanation, style: const TextStyle(height: 1.7)),
      ),
      const SizedBox(height: 14),
      if (_answered) FilledButton(
        onPressed: () => setState(() {
          _questionIndex++;
          _selected = null;
          _answered = false;
        }),
        child: Text(_questionIndex == questions.length - 1 ? 'عرض النتيجة' : 'السؤال التالي'),
      ),
    ]);
  }

  Future<void> _answer(int index) async {
    final question = widget.lesson.quiz[_questionIndex];
    final correct = index == question.answerIndex;
    setState(() {
      _selected = index;
      _answered = true;
      if (correct) _score++;
    });
    // Tie quiz performance to review scheduling, so missed vocabulary returns sooner.
    final words = widget.lesson.vocabulary;
    if (words.isNotEmpty) {
      final word = words[_questionIndex % words.length];
      await LearningStore.instance.recordWord(
        lessonId: widget.lesson.id,
        term: word.term,
        meaning: word.meaning,
        correct: correct,
      );
    }
  }

  void _resetQuiz() => setState(() {
    _questionIndex = 0;
    _score = 0;
    _selected = null;
    _answered = false;
  });

  Future<void> _completeLesson() async {
    await LearningStore.instance.markLessonComplete(widget.lesson.id);
    if (!mounted) return;
    setState(() => _finished = true);
  }

  Widget _completion() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle_rounded, size: 58, color: Colors.green),
        const SizedBox(height: 12),
        const Text('أحسنت! أكملت الدرس', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('نتيجتك: $_score من ${widget.lesson.quiz.length}'),
        const SizedBox(height: 18),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('العودة إلى المسار')),
      ]),
    ),
  );
}

class _ReviewList extends StatefulWidget {
  const _ReviewList({required this.lessons});
  final List<LearningLesson> lessons;

  @override
  State<_ReviewList> createState() => _ReviewListState();
}

class _ReviewListState extends State<_ReviewList> {
  late Future<Map<String, WordProgress>> _future;

  @override
  void initState() {
    super.initState();
    _future = LearningStore.instance.loadProgress();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, WordProgress>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      final all = (snapshot.data ?? {}).values.toList()
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
      final due = all.where((item) => item.isDue).toList();
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xFFEAF0FF), borderRadius: BorderRadius.circular(16)),
            child: Text('لديك ${due.length} كلمة حان موعد مراجعتها من أصل ${all.length} كلمة مسجلة. الإجابات الخاطئة تعود للمراجعة في وقت أقرب.', style: const TextStyle(height: 1.8)),
          ),
          const SizedBox(height: 14),
          if (all.isEmpty)
            const Card(child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('ابدأ درسًا ثم أجب عن أسئلته حتى تتكون قائمة مراجعتك الشخصية.'),
            )),
          for (final item in all)
            Card(child: ListTile(
              leading: Icon(item.isDue ? Icons.notifications_active_outlined : Icons.schedule_rounded,
                  color: item.isDue ? Colors.deepOrange : Colors.blueGrey),
              title: Text(item.term, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${item.meaning}\nالصحيحة: ${item.correctCount} · الأخطاء: ${item.wrongCount}'),
              isThreeLine: true,
              trailing: Text(item.isDue ? 'مستحقة' : _remaining(item.dueAt)),
            )),
        ],
      );
    },
  );

  String _remaining(DateTime due) {
    final days = due.difference(DateTime.now()).inDays;
    if (days <= 0) return 'اليوم';
    if (days == 1) return 'غدًا';
    return 'بعد $days أيام';
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? const Color(0xFFEAF0FF) : null,
        side: BorderSide(color: selected ? const Color(0xFF4968E8) : const Color(0xFFDDE3EF)),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );
}
