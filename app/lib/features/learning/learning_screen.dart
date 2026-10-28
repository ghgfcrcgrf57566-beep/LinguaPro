import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';

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
  Set<String> _completedIds = <String>{};
  Map<String, QuizResult> _bestQuizResults = <String, QuizResult>{};

  @override
  void initState() {
    super.initState();
    _lessonsFuture = _loadLessons();
    _loadCompletedLessons();
  }

  Future<void> _loadCompletedLessons() async {
    final completed = await LearningStore.instance.completedLessons();
    final bestResults = await LearningStore.instance.bestQuizResults();
    if (mounted) {
      setState(() {
        _completedIds = completed;
        _bestQuizResults = bestResults;
      });
    }
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
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF3FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('إنجازك: ${lessons.where((lesson) => _completedIds.contains(lesson.id)).length} من ${lessons.length} دروس',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF334C82))),
                  const SizedBox(height: 9),
                  LinearProgressIndicator(
                    value: lessons.isEmpty ? 0 : lessons.where((lesson) => _completedIds.contains(lesson.id)).length / lessons.length,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  const SizedBox(height: 6),
                  const Text('يُحتسب الدرس بعد إنهاء الاختبار وحفظ النتيجة.', style: TextStyle(fontSize: 11, color: Color(0xFF687590))),
                ]),
              ),
              const SizedBox(height: 10),
              for (var index = 0; index < lessons.length; index++) ...[
                Builder(builder: (context) {
                  final lesson = lessons[index];
                  final isLocked = index > 0 && !_completedIds.contains(lessons[index - 1].id);
                  final isCompleted = _completedIds.contains(lesson.id);
                  return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    leading: CircleAvatar(
                      backgroundColor: isLocked ? Colors.grey.shade200 : (lesson.isLegal ? const Color(0xFFFFF0D3) : const Color(0xFFEAF0FF)),
                      child: isCompleted
                          ? const Icon(Icons.check_rounded, color: Colors.green)
                          : isLocked
                              ? const Icon(Icons.lock_outline_rounded, color: Colors.grey)
                              : Center(child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4059A7)))),
                    ),
                    title: Text(lesson.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${lesson.description}\n${lesson.vocabulary.length} مفردات · ${lesson.quiz.length} أسئلة'
                        '${_bestQuizResults[lesson.id] == null ? '' : '\nأفضل نتيجة: ${_bestQuizResults[lesson.id]!.score}/${_bestQuizResults[lesson.id]!.total}'}',
                      ),
                    ),
                    isThreeLine: true,
                    trailing: isCompleted
                        ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                        : Icon(isLocked ? Icons.lock_rounded : Icons.chevron_left_rounded, color: isLocked ? Colors.grey : null),
                    onTap: () async {
                      if (isLocked) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('مفاجأة قريبة! أكمل المرحلة السابقة أولًا لفتح هذه المرحلة.'),
                        ));
                        return;
                      }
                      await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => LessonScreen(lesson: lesson),
                      ));
                      await _loadCompletedLessons();
                    },
                  ));
                }),
              ],
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
  bool _meaningVisible = false;
  bool _answered = false;
  int _selectedAnswerIndex = -1;
  int _score = 0;
  bool _finished = false;
  int _listenIndex = 0;
  int _listenSelected = -1;
  bool _listenAnswered = false;
  List<int> _listenOptionIndices = <int>[];
  int _earnedXp = 0;
  int _totalXp = 0;
  String _newBadge = '';
  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;

  Future<void> _speak(String text) async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.42);
      await _tts.setPitch(1.0);
      await _tts.stop();
      if (mounted) setState(() => _speaking = true);
      await _tts.speak(text);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر تشغيل النطق. تحقق من تثبيت محرك تحويل النص إلى كلام في الجهاز.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

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
              const SizedBox(width: 8),
              _ModeChip(label: 'الاستماع', selected: _tab == 3, onTap: () => setState(() => _tab = 3)),
            ]),
          ),
          Expanded(child: IndexedStack(
            index: _tab,
            children: [_vocabulary(), _sections(), _quiz(), _listeningPractice()],
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
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(child: Text(word.term, textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF263E81)))),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'استمع إلى النطق الإنجليزي',
                onPressed: _speaking ? null : () => _speak(word.term),
                icon: const Icon(Icons.volume_up_rounded),
              ),
            ]),
            if (word.pronunciation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('مساعدة للنطق: ${word.pronunciation}', style: const TextStyle(color: Colors.grey)),
            ],
            const SizedBox(height: 18),
            if (_meaningVisible) ...[
              Text(word.meaning, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const Divider(height: 30),
              Text(word.example, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
            ] else
              const Text('حاول تذكر المعنى قبل إظهاره', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, height: 1.7)),
          ]),
        )),
        const SizedBox(height: 16),
        if (!_meaningVisible)
          FilledButton.icon(
            onPressed: () => setState(() => _meaningVisible = true),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('أظهر المعنى'),
          )
        else ...[
          const Text('قيّم تذكرك بصدق حتى يحدد التطبيق موعد المراجعة الأنسب.', textAlign: TextAlign.center, style: TextStyle(height: 1.7)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => _rateWord(false),
              icon: const Icon(Icons.replay_rounded),
              label: const Text('لم أتذكرها'),
            )),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.icon(
              onPressed: () => _rateWord(true),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('تذكرتها'),
            )),
          ]),
        ],
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => setState(() => _tab = 1),
          child: const Text('قراءة الشرح والأمثلة'),
        ),
        OutlinedButton(
          onPressed: () => setState(() => _tab = 2),
          child: const Text('انتقل إلى الاختبار'),
        ),
      ],
    );
  }

  Future<void> _rateWord(bool remembered) async {
    final word = widget.lesson.vocabulary[_wordIndex];
    await LearningStore.instance.recordWord(
      lessonId: widget.lesson.id,
      term: word.term,
      meaning: word.meaning,
      correct: remembered,
    );
    if (!mounted) return;
    if (_wordIndex >= widget.lesson.vocabulary.length - 1) {
      setState(() {
        _tab = 2;
        _meaningVisible = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('انتهت مراجعة المفردات. أكمل الاختبار لتثبيت ما تعلمته.'),
      ));
    } else {
      setState(() {
        _wordIndex++;
        _meaningVisible = false;
      });
    }
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

  Widget _listeningPractice() {
    final words = widget.lesson.vocabulary;
    if (words.length < 2) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('يحتاج تدريب الاستماع إلى مفردتين على الأقل في هذا الدرس.'),
      ));
    }
    if (_listenIndex >= words.length) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.headphones_rounded, size: 52, color: Color(0xFFE0A92E)),
          const SizedBox(height: 12),
          const Text('أحسنت! أنهيت تدريب الاستماع 🎧', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => setState(() {
            _listenIndex = 0;
            _listenSelected = -1;
            _listenAnswered = false;
            _listenOptionIndices = <int>[];
          }), child: const Text('تدرب مرة أخرى')),
        ]),
      ));
    }
    final target = words[_listenIndex];
    if (_listenOptionIndices.isEmpty) {
      final alternatives = List<int>.generate(words.length, (i) => i)..remove(_listenIndex);
      _listenOptionIndices = <int>[_listenIndex, ...alternatives.take(3)];
      _listenOptionIndices.shuffle(math.Random(widget.lesson.id.hashCode + _listenIndex));
    }
    final correctOption = _listenOptionIndices.indexOf(_listenIndex);
    return ListView(padding: const EdgeInsets.all(18), children: [
      LinearProgressIndicator(value: (_listenIndex + 1) / words.length, minHeight: 6),
      const SizedBox(height: 18),
      Text('تمرين الاستماع ${_listenIndex + 1} من ${words.length}', style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 20),
      Card(child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(children: [
          const Icon(Icons.hearing_rounded, size: 46, color: Color(0xFF334C82)),
          const SizedBox(height: 10),
          const Text('استمع إلى الكلمة ثم اختر معناها', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _speaking ? null : () => _speak(target.term),
            icon: const Icon(Icons.volume_up_rounded),
            label: const Text('استمع مرة أخرى'),
          ),
        ]),
      )),
      const SizedBox(height: 14),
      for (var i = 0; i < _listenOptionIndices.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(14),
              alignment: Alignment.centerRight,
              side: BorderSide(color: _listenAnswered && i == correctOption ? Colors.green : _listenAnswered && i == _listenSelected ? Colors.red : const Color(0xFFDDE3EF)),
              backgroundColor: _listenAnswered && i == correctOption ? const Color(0xFFE7F7EC) : _listenAnswered && i == _listenSelected ? const Color(0xFFFFEBEE) : null,
            ),
            onPressed: _listenAnswered ? null : () => setState(() {
              _listenSelected = i;
              _listenAnswered = true;
            }),
            child: Text(words[_listenOptionIndices[i]].meaning),
          ),
        ),
      if (_listenAnswered) ...[
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(_listenSelected == correctOption ? 'إجابة صحيحة! رائع 👏' : 'ليس تمامًا. الكلمة كانت: ${target.term} — ${target.meaning}', style: const TextStyle(height: 1.7)),
        ),
        FilledButton(
          onPressed: () => setState(() {
            _listenIndex++;
            _listenSelected = -1;
            _listenAnswered = false;
            _listenOptionIndices = <int>[];
          }),
          child: Text(_listenIndex == words.length - 1 ? 'إنهاء التدريب' : 'التالي'),
        ),
      ],
    ]);
  }

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
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(question.question, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, height: 1.6))),
        IconButton(tooltip: 'استمع إلى السؤال', onPressed: _speaking ? null : () => _speak(question.question), icon: const Icon(Icons.volume_up_rounded)),
      ]),
      const SizedBox(height: 18),
      for (var i = 0; i < question.options.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.all(15),
              side: BorderSide(
                color: !_answered
                    ? const Color(0xFFDDE3EF)
                    : i == question.answerIndex
                        ? Colors.green
                        : i == _selectedAnswerIndex
                            ? Colors.red
                            : const Color(0xFFDDE3EF),
              ),
              backgroundColor: !_answered
                  ? null
                  : i == question.answerIndex
                      ? const Color(0xFFE7F7EC)
                      : i == _selectedAnswerIndex
                          ? const Color(0xFFFFEBEE)
                          : null,
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
          _answered = false;
          _selectedAnswerIndex = -1;
        }),
        child: Text(_questionIndex == questions.length - 1 ? 'عرض النتيجة' : 'السؤال التالي'),
      ),
    ]);
  }

  void _answer(int index) {
    final question = widget.lesson.quiz[_questionIndex];
    final correct = index == question.answerIndex;
    setState(() {
      _answered = true;
      _selectedAnswerIndex = index;
      if (correct) _score++;
    });
  }

  void _resetQuiz() => setState(() {
    _questionIndex = 0;
    _score = 0;
    _answered = false;
    _selectedAnswerIndex = -1;
  });

  Future<void> _completeLesson() async {
    await LearningStore.instance.recordQuizResult(
      lessonId: widget.lesson.id,
      score: _score,
      total: widget.lesson.quiz.length,
    );
    final completed = await LearningStore.instance.completedLessons();
    if (!completed.contains(widget.lesson.id)) {
      _earnedXp = 10;
      await LearningStore.instance.awardLessonXp(widget.lesson.id);
      final completedCount = completed.length + 1;
      const badges = <int, String>{
        1: 'شارة البداية 🥉',
        3: 'شارة المثابرة 🥈',
        5: 'شارة المتعلم النشيط 🥇',
        10: 'شارة خبير المسار 🏆',
      };
      _newBadge = badges[completedCount] ?? '';
    }
    await LearningStore.instance.markLessonComplete(widget.lesson.id);
    _totalXp = await LearningStore.instance.totalXp();
    if (!mounted) return;
    setState(() => _finished = true);
  }

  Widget _completion() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 650),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Color(0xFFFFE7A3), Color(0xFFFFC94F), Color(0xFFFFF3CC)]),
            boxShadow: [BoxShadow(color: const Color(0xFFFFC94F).withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 3)],
          ),
          child: const Icon(Icons.auto_awesome_rounded, size: 48, color: Color(0xFF5B3C00)),
        ),
        const SizedBox(height: 16),
        const Text('مفاجأة! فتحت إنجازًا جديدًا 🎉', textAlign: TextAlign.center, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('أكملت: ${widget.lesson.title}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('نتيجتك: $_score من ${widget.lesson.quiz.length}'),
        const SizedBox(height: 8),
        Text(_earnedXp > 0 ? 'مكافأتك: +$_earnedXp XP ⭐' : 'أعدت الدرس؛ نقاط الخبرة لا تتكرر لنفس المرحلة.'),
        Text('إجمالي الخبرة: $_totalXp XP'),
        if (_newBadge.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFFFF0D3), borderRadius: BorderRadius.circular(14)),
            child: Text('شارة جديدة: $_newBadge', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
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
            child: Text('لديك ${due.length} كلمة حان موعد مراجعتها من أصل ${all.length} كلمة مسجلة. يتضمن المحتوى الحالي ${widget.lessons.fold<int>(0, (sum, lesson) => sum + lesson.vocabulary.length)} مفردة تعليمية. الكلمات التي لم تتذكرها تعود للمراجعة بعد نحو أربع ساعات، ثم تتباعد المواعيد مع نجاح التذكر.', style: const TextStyle(height: 1.8)),
          ),
          const SizedBox(height: 14),
          if (all.any((item) => item.needsExtraPractice))
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ReviewSessionScreen(weakOnly: true),
              )).then((_) {
                if (mounted) {
                  setState(() {
                    _future = LearningStore.instance.loadProgress();
                  });
                }
              }),
              icon: const Icon(Icons.psychology_alt_rounded),
              label: Text('تدرب على الكلمات الصعبة ${all.where((item) => item.needsExtraPractice).length}'),
            ),
          if (due.isNotEmpty)
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ReviewSessionScreen(),
              )).then((_) {
                if (mounted) {
                  setState(() {
                    _future = LearningStore.instance.loadProgress();
                  });
                }
              }),
              icon: const Icon(Icons.replay_circle_filled_rounded),
              label: Text('ابدأ مراجعة ${due.length} كلمة مستحقة'),
            ),
          if (all.isEmpty)
            const Card(child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('ابدأ درسًا ثم قيّم تذكرك للكلمات حتى تتكون قائمة مراجعتك الشخصية.'),
            )),
          for (final item in all)
            Card(child: ListTile(
              leading: Icon(item.isDue ? Icons.notifications_active_outlined : Icons.schedule_rounded,
                  color: item.isDue ? Colors.deepOrange : Colors.blueGrey),
              title: Text(item.term, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${item.meaning}\nدقة التذكر: ${(item.accuracy * 100).round()}% · الصحيحة: ${item.correctCount} · الأخطاء: ${item.wrongCount}${item.needsExtraPractice ? '\nتحتاج إلى تدريب إضافي' : ''}'),
              isThreeLine: true,
              trailing: Text(item.isDue ? 'مستحقة' : _remaining(item.dueAt)),
            )),
        ],
      );
    },
  );

  String _remaining(DateTime due) {
    final difference = due.difference(DateTime.now());
    if (difference.inHours < 24) return 'لاحقًا اليوم';
    final days = difference.inDays;
    if (days == 1) return 'غدًا';
    return 'بعد $days أيام';
  }
}


class ReviewSessionScreen extends StatefulWidget {
  const ReviewSessionScreen({super.key, this.weakOnly = false});
  final bool weakOnly;

  @override
  State<ReviewSessionScreen> createState() => _ReviewSessionScreenState();
}

class _ReviewSessionScreenState extends State<ReviewSessionScreen> {
  late Future<List<WordProgress>> _dueFuture;
  int _index = 0;
  bool _showMeaning = false;

  @override
  void initState() {
    super.initState();
    _dueFuture = _loadDue();
  }

  Future<List<WordProgress>> _loadDue() async {
    final progress = await LearningStore.instance.loadProgress();
    final due = progress.values.where((item) => widget.weakOnly ? item.needsExtraPractice : item.isDue).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return due;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.weakOnly ? 'تدريب الكلمات الصعبة' : 'مراجعة الكلمات')),
    body: FutureBuilder<List<WordProgress>>(
      future: _dueFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final words = snapshot.data ?? const <WordProgress>[];
        if (_index >= words.length) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.celebration_rounded, size: 56, color: Color(0xFFE0A92E)),
              const SizedBox(height: 12),
              const Text('أكملت مراجعة الكلمات المستحقة!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('ستعود الكلمات التي احتجت إلى مراجعتها لاحقًا، وستتباعد المواعيد للكلمات التي تتذكرها.', textAlign: TextAlign.center, style: TextStyle(height: 1.8)),
              const SizedBox(height: 18),
              FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('العودة إلى مركز المراجعة')),
            ]),
          ));
        }
        final word = words[_index];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            LinearProgressIndicator(value: (_index + 1) / words.length, minHeight: 6),
            const SizedBox(height: 18),
            Text('الكلمة ${_index + 1} من ${words.length}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            Card(child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(children: [
                Text(word.term, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF263E81))),
                const SizedBox(height: 22),
                if (_showMeaning)
                  Text(word.meaning, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700))
                else
                  const Text('حاول تذكر المعنى قبل إظهاره', textAlign: TextAlign.center, style: TextStyle(height: 1.7)),
              ]),
            )),
            const SizedBox(height: 18),
            if (!_showMeaning)
              FilledButton.icon(
                onPressed: () => setState(() => _showMeaning = true),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('أظهر المعنى'),
              )
            else ...[
              const Text('هل تذكرت المعنى قبل إظهاره؟', textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => _rate(word, false),
                  child: const Text('لم أتذكرها'),
                )),
                const SizedBox(width: 10),
                Expanded(child: FilledButton(
                  onPressed: () => _rate(word, true),
                  child: const Text('تذكرتها'),
                )),
              ]),
            ],
          ],
        );
      },
    ),
  );

  Future<void> _rate(WordProgress word, bool remembered) async {
    await LearningStore.instance.recordWord(
      lessonId: word.lessonId,
      term: word.term,
      meaning: word.meaning,
      correct: remembered,
    );
    if (!mounted) return;
    setState(() {
      _index++;
      _showMeaning = false;
    });
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
