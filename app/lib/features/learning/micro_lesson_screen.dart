import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../models/learning_lesson.dart';
import '../../services/learning_engine.dart';
import '../../services/learning_sound_service.dart';
import '../../services/learning_store.dart';
import 'learning_screen.dart';
import 'micro_lesson_flow.dart';

class MicroLessonScreen extends StatefulWidget {
  const MicroLessonScreen({super.key, required this.lesson});

  final LearningLesson lesson;

  @override
  State<MicroLessonScreen> createState() => _MicroLessonScreenState();
}

class _MicroLessonScreenState extends State<MicroLessonScreen> {
  late final List<MicroLessonStep> _steps;
  final FlutterTts _tts = FlutterTts();
  final int _sessionId = DateTime.now().microsecondsSinceEpoch;
  final DateTime _startedAt = DateTime.now();
  final List<MicroLessonStep> _mistakes = <MicroLessonStep>[];
  final Set<String> _queuedMistakeIds = <String>{};
  final Map<String, int> _attemptsByStep = <String, int>{};
  final List<String> _wordBankSelection = <String>[];

  int _index = 0;
  int _reviewIndex = 0;
  int? _selectedOption;
  int _hearts = 5;
  int _firstTryCorrect = 0;
  int _gradedMainAttempts = 0;
  int _totalCorrect = 0;
  int _earnedXp = 0;
  int _totalXp = 0;
  bool _inReview = false;
  bool _showFeedback = false;
  bool _lastCorrect = false;
  bool _saving = false;
  bool _speaking = false;
  bool _completed = false;

  MicroLessonStep? get _currentStep {
    if (_inReview) {
      if (_reviewIndex >= _mistakes.length) return null;
      return _mistakes[_reviewIndex];
    }
    if (_index >= _steps.length) return null;
    return _steps[_index];
  }

  @override
  void initState() {
    super.initState();
    _steps = MicroLessonFlow.build(widget.lesson);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak(String text, {bool slow = false}) async {
    if (text.trim().isEmpty || _speaking) return;
    setState(() => _speaking = true);
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(slow ? 0.25 : 0.42);
      await _tts.setPitch(1.0);
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تشغيل النطق على هذا الجهاز.')),
        );
      }
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  Future<void> _submit() async {
    final step = _currentStep;
    if (step == null || _saving || _showFeedback || !step.isAutoGraded) return;

    String answer;
    bool correct;
    if (step.type == MicroStepType.wordBank) {
      if (_wordBankSelection.isEmpty) {
        _showMessage('اختر الكلمات ورتبها أولًا.');
        return;
      }
      answer = _wordBankSelection.map(_tokenFromKey).join(' ');
      correct = LearningEngine.matchesAnswer(answer, step.acceptedAnswers);
    } else {
      if (_selectedOption == null ||
          _selectedOption! < 0 ||
          _selectedOption! >= step.options.length) {
        _showMessage('اختر إجابة أولًا.');
        return;
      }
      answer = step.options[_selectedOption!];
      correct = _selectedOption == step.answerIndex;
    }

    setState(() => _saving = true);
    final isReview = _inReview;
    final attemptNumber = (_attemptsByStep[step.id] ?? 0) + 1;
    _attemptsByStep[step.id] = attemptNumber;
    final eventId = 'micro:$_sessionId:${step.id}:${isReview ? 'review' : 'main'}:$attemptNumber';
    try {
      await LearningEngine.instance.recordAnswer(
        eventId: eventId,
        lessonId: widget.lesson.id,
        prompt: step.prompt,
        answer: answer,
        correct: correct,
        targetTerm: step.word?.term,
        targetMeaning: step.word?.meaning,
      );
      final word = step.word;
      if (word != null) {
        await LearningStore.instance.recordWord(
          lessonId: widget.lesson.id,
          term: word.term,
          meaning: word.meaning,
          correct: correct,
          eventId: '$eventId:spaced-review',
        );
      }
      if (correct) {
        await LearningEngine.instance.awardXp(eventId: '$eventId:xp', points: 1);
        await LearningSoundService.instance.correct();
        await HapticFeedback.lightImpact();
      } else {
        await LearningSoundService.instance.incorrect();
        await HapticFeedback.mediumImpact();
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _showFeedback = true;
        _lastCorrect = correct;
        if (correct) {
          _totalCorrect++;
          if (!isReview) _firstTryCorrect++;
        } else {
          _hearts = math.max(0, _hearts - 1);
          if (!isReview && _queuedMistakeIds.add(step.id)) {
            _mistakes.add(step);
          }
        }
        if (!isReview) _gradedMainAttempts++;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('تعذر حفظ الإجابة. تحقق من الاتصال المحلي وحاول مجددًا.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _advance() async {
    if (_saving) return;
    final step = _currentStep;
    if (step == null) return;

    if (_inReview) {
      if (!_lastCorrect) {
        setState(() {
          _showFeedback = false;
          _selectedOption = null;
          _wordBankSelection.clear();
        });
        return;
      }
      if (_reviewIndex + 1 < _mistakes.length) {
        setState(() {
          _reviewIndex++;
          _showFeedback = false;
          _selectedOption = null;
          _wordBankSelection.clear();
        });
      } else {
        await _finishLesson();
      }
      return;
    }

    if (_index + 1 < _steps.length) {
      setState(() {
        _index++;
        _showFeedback = false;
        _selectedOption = null;
        _wordBankSelection.clear();
      });
      return;
    }

    if (_mistakes.isNotEmpty) {
      setState(() {
        _inReview = true;
        _reviewIndex = 0;
        _showFeedback = false;
        _selectedOption = null;
        _wordBankSelection.clear();
      });
    } else {
      await _finishLesson();
    }
  }

  Future<void> _finishLesson() async {
    if (_completed || _saving) return;
    setState(() => _saving = true);
    try {
      final total = _gradedMainAttempts;
      final score = _firstTryCorrect.clamp(0, total).toInt();
      await LearningStore.instance.recordQuizResult(
        lessonId: widget.lesson.id,
        score: score,
        total: total,
      );
      final xpBefore = await LearningEngine.instance.totalXp();
      await LearningEngine.instance.completeLesson(
        lessonId: widget.lesson.id,
        completionEventId: 'micro-lesson-complete:${widget.lesson.id}',
        xp: 10,
      );
      await LearningStore.instance.markLessonComplete(widget.lesson.id);
      await LearningSoundService.instance.complete();
      await HapticFeedback.heavyImpact();
      final xpAfter = await LearningEngine.instance.totalXp();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _earnedXp = xpAfter - xpBefore;
        _totalXp = xpAfter;
        _completed = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('تعذر حفظ إنجاز الدرس. حاول إنهاء الدرس مرة أخرى.');
    }
  }

  void _continuePresentation() {
    if (_saving) return;
    _advance();
  }

  @override
  Widget build(BuildContext context) {
    final step = _currentStep;
    if (_completed || step == null) return _completionScreen();

    final totalMain = _steps.length;
    final progress = _inReview
        ? 0.88 + (0.10 * ((_reviewIndex + 1) / math.max(1, _mistakes.length)))
        : (_index + 1) / (totalMain + (_mistakes.isNotEmpty ? 1 : 0) + 1);
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF7),
      appBar: AppBar(
        title: Text(widget.lesson.isLegal ? 'الدرس القانوني المصغّر' : 'درس LinguaPro المصغّر'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 14),
            child: Center(
              child: Row(children: [
                const Icon(Icons.favorite_rounded, color: Color(0xFFFF5A65), size: 19),
                const SizedBox(width: 4),
                Text('$_hearts', style: const TextStyle(fontWeight: FontWeight.w900)),
              ]),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
            child: Row(children: [
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0).toDouble(),
                  minHeight: 9,
                  backgroundColor: const Color(0xFFE1E9E2),
                  color: const Color(0xFF58CC02),
                ),
              )),
              const SizedBox(width: 12),
              Text(_inReview ? 'مراجعة الأخطاء' : '${_index + 1}/$totalMain',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF405346))),
            ]),
          ),
          Expanded(child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            children: [
              if (_inReview) Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFFF1C9), borderRadius: BorderRadius.circular(12)),
                child: Text('إعادة تدريب ${_reviewIndex + 1} من ${_mistakes.length} — أكملها بإجابة صحيحة.',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 8),
              Text(step.prompt, style: const TextStyle(fontSize: 23, height: 1.45, fontWeight: FontWeight.w900, color: Color(0xFF26352B))),
              const SizedBox(height: 18),
              _buildStepContent(step),
              if (_showFeedback) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _lastCorrect ? const Color(0xFFD7FFB8) : const Color(0xFFFFDFDF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _lastCorrect ? const Color(0xFF58CC02) : const Color(0xFFEA2B2B)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      _lastCorrect ? _encouragement(step.id) : 'الإجابة الصحيحة: ${step.type == MicroStepType.wordBank ? step.acceptedAnswers.join(' / ') : (step.answerIndex != null && step.answerIndex! < step.options.length ? step.options[step.answerIndex!] : step.explanation)}',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        fontWeight: FontWeight.w900,
                        color: _lastCorrect ? const Color(0xFF245C10) : const Color(0xFFB51F28),
                      ),
                    ),
                    if (_lastCorrect && step.explanation.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(step.explanation, style: const TextStyle(height: 1.6)),
                    ],
                  ]),
                ),
              ],
            ],
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _showFeedback && _lastCorrect ? const Color(0xFF58CC02) : const Color(0xFF246B4B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _saving ? null : _buttonAction(step),
                child: Text(_buttonLabel(step), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  VoidCallback? _buttonAction(MicroLessonStep step) {
    if (_saving) return null;
    if (step.isPresentation || step.isSelfAssessed) {
      if (_showFeedback) return _advance;
      return _continuePresentation;
    }
    if (!_showFeedback) return _submit;
    if (_inReview && !_lastCorrect) return _advance;
    return _advance;
  }

  String _buttonLabel(MicroLessonStep step) {
    if (_saving) return 'جارٍ الحفظ…';
    if (step.isPresentation) return 'متابعة';
    if (step.isSelfAssessed) return 'أنهيت تدريب النطق';
    if (!_showFeedback) return 'تحقّق';
    if (_inReview && !_lastCorrect) return 'حاول مرة أخرى';
    if (_index == _steps.length - 1 && !_inReview && _mistakes.isEmpty) return 'عرض المكافآت';
    return 'المتابعة';
  }

  Widget _buildStepContent(MicroLessonStep step) {
    if (step.isPresentation) {
      final word = step.word!;
      return Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFDCE8DD))),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEAF8E1)),
              child: Icon(_iconForMeaning(word.meaning), size: 52, color: const Color(0xFF347B2B)),
            ),
            const SizedBox(height: 16),
            Text(word.term, textAlign: TextAlign.center, style: const TextStyle(fontSize: 31, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(word.meaning, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
            if (word.pronunciation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('مساعدة النطق: ${word.pronunciation}', style: const TextStyle(color: Colors.blueGrey)),
            ],
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _speaking ? null : () => _speak(word.term),
              icon: const Icon(Icons.volume_up_rounded),
              label: const Text('استمع إلى الكلمة'),
            ),
            const SizedBox(height: 8),
            Text(step.example, textAlign: TextAlign.center, style: const TextStyle(height: 1.6)),
            OutlinedButton.icon(
              onPressed: _speaking ? null : () => _speak(step.example, slow: true),
              icon: const Icon(Icons.slow_motion_video_rounded),
              label: const Text('استمع ببطء إلى المثال'),
            ),
          ]),
        ),
      );
    }

    if (step.type == MicroStepType.speakingPractice) {
      return Card(
        elevation: 0,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const Icon(Icons.record_voice_over_rounded, size: 64, color: Color(0xFF347B2B)),
            const SizedBox(height: 12),
            Text(step.spokenText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.6)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
              OutlinedButton.icon(onPressed: _speaking ? null : () => _speak(step.spokenText), icon: const Icon(Icons.volume_up_rounded), label: const Text('النطق العادي')),
              OutlinedButton.icon(onPressed: _speaking ? null : () => _speak(step.spokenText, slow: true), icon: const Icon(Icons.slow_motion_video_rounded), label: const Text('النطق البطيء')),
            ]),
            const SizedBox(height: 10),
            const Text('تدرّب بصوتك ثم قيّم نفسك. لا يسجّل هذا الإصدار الميكروفون ولا يصحح النطق آليًا.',
                textAlign: TextAlign.center, style: TextStyle(height: 1.6, color: Colors.blueGrey)),
          ]),
        ),
      );
    }

    if (step.type == MicroStepType.wordBank) {
      final available = <String>[];
      final counts = <String, int>{};
      for (final token in step.options) {
        final key = '${token}_${counts[token] ?? 0}';
        counts[token] = (counts[token] ?? 0) + 1;
        if (!_wordBankSelection.contains(key)) available.add(key);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_wordBankSelection.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFDCE8DD))),
            child: const Text('اختر الكلمات بالترتيب الصحيح', style: TextStyle(color: Colors.blueGrey)),
          )
        else
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < _wordBankSelection.length; i++)
              InputChip(
                label: Text(_tokenFromKey(_wordBankSelection[i])),
                onDeleted: _showFeedback ? null : () => setState(() => _wordBankSelection.removeAt(i)),
                backgroundColor: const Color(0xFFD7FFB8),
              ),
          ]),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final key in available)
            ActionChip(
              label: Text(_tokenFromKey(key)),
              onPressed: _showFeedback ? null : () => setState(() => _wordBankSelection.add(key)),
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFB9CBB9)),
            ),
        ]),
      ]);
    }

    final options = step.options;
    return Column(children: [
      if (step.type == MicroStepType.audioChoice)
        Center(child: Wrap(spacing: 10, children: [
          OutlinedButton.icon(onPressed: _speaking ? null : () => _speak(step.spokenText), icon: const Icon(Icons.volume_up_rounded), label: const Text('استمع')),
          OutlinedButton.icon(onPressed: _speaking ? null : () => _speak(step.spokenText, slow: true), icon: const Icon(Icons.slow_motion_video_rounded), label: const Text('ببطء')),
        ])),
      const SizedBox(height: 10),
      for (var i = 0; i < options.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OutlinedButton(
            onPressed: _showFeedback ? null : () => setState(() => _selectedOption = i),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.all(15),
              backgroundColor: _showFeedback && i == step.answerIndex
                  ? const Color(0xFFD7FFB8)
                  : !_showFeedback && _selectedOption == i
                      ? const Color(0xFFEAF8E1)
                      : Colors.white,
              side: BorderSide(
                color: _showFeedback && i == step.answerIndex
                    ? const Color(0xFF58CC02)
                    : _showFeedback && _selectedOption == i && !_lastCorrect
                        ? const Color(0xFFEA2B2B)
                        : _selectedOption == i
                            ? const Color(0xFF58CC02)
                            : const Color(0xFFDCE8DD),
                width: 1.4,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Row(children: [
              if (step.type == MicroStepType.imageChoice)
                Container(
                  width: 42,
                  height: 42,
                  margin: const EdgeInsetsDirectional.only(end: 12),
                  decoration: BoxDecoration(color: const Color(0xFFEAF8E1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(_iconForMeaning(options[i]), color: const Color(0xFF347B2B)),
                ),
              Expanded(child: Text(options[i], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              if (_showFeedback && i == step.answerIndex) const Icon(Icons.check_circle_rounded, color: Color(0xFF347B2B)),
            ]),
          ),
        ),
    ]);
  }

  String _tokenFromKey(String key) {
    final separator = key.lastIndexOf('_');
    return separator < 0 ? key : key.substring(0, separator);
  }

  IconData _iconForMeaning(String text) {
    final value = text.toLowerCase();
    if (value.contains('محام') || value.contains('lawyer')) return Icons.gavel_rounded;
    if (value.contains('موكل') || value.contains('عميل') || value.contains('client')) return Icons.person_rounded;
    if (value.contains('محكم') || value.contains('court')) return Icons.account_balance_rounded;
    if (value.contains('مكتب') || value.contains('office')) return Icons.business_rounded;
    if (value.contains('قاض') || value.contains('judge')) return Icons.balance_rounded;
    if (value.contains('مستند') || value.contains('document')) return Icons.description_rounded;
    if (value.contains('موعد') || value.contains('appointment')) return Icons.calendar_month_rounded;
    if (value.contains('كتاب') || value.contains('book')) return Icons.menu_book_rounded;
    return Icons.lightbulb_outline_rounded;
  }

  String _encouragement(String seed) {
    const messages = <String>['ممتاز!', 'رائع!', 'إجابة مذهلة!'];
    final value = seed.codeUnits.fold<int>(0, (sum, item) => sum + item);
    return messages[value % messages.length];
  }

  Widget _completionScreen() {
    final accuracy = _gradedMainAttempts == 0 ? 100 : ((_firstTryCorrect / _gradedMainAttempts) * 100).round();
    final elapsed = DateTime.now().difference(_startedAt);
    final duration = elapsed.inMinutes > 0
        ? '${elapsed.inMinutes} دقيقة و${elapsed.inSeconds.remainder(60)} ثانية'
        : '${elapsed.inSeconds} ثانية';
    return Scaffold(
      appBar: AppBar(title: const Text('إنجاز الدرس')),
      body: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFFFFE7A3), Color(0xFFFFC94F)])),
            child: const Icon(Icons.emoji_events_rounded, size: 62, color: Color(0xFF654500)),
          ),
          const SizedBox(height: 18),
          const Text('أحسنت! أكملت الدرس 🎉', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(widget.lesson.title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          _stat('الدقة من المحاولة الأولى', '$accuracy%'),
          _stat('الإجابات الصحيحة، مع المراجعة', '$_totalCorrect'),
          _stat('الوقت المستغرق', duration),
          _stat('النقاط المكتسبة', '+$_earnedXp XP'),
          _stat('إجمالي نقاطك', '$_totalXp XP'),
          _stat('الأخطاء التي راجعتها', '${_mistakes.length}'),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('العودة إلى خريطة التعلّم'),
          )),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: OutlinedButton(
            onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) => LessonScreen(lesson: widget.lesson),
            )),
            child: const Text('فتح المحتوى الكامل والشرح'),
          )),
        ]),
      )),
    );
  }

  Widget _stat(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF66736B)))),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
    ]),
  );
}
