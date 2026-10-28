import 'package:flutter/material.dart';

import '../../services/learning_store.dart';
import '../../services/learning_engine.dart';

class SpacedReviewScreen extends StatefulWidget {
  const SpacedReviewScreen({super.key});
  @override
  State<SpacedReviewScreen> createState() => _SpacedReviewScreenState();
}

class _SpacedReviewScreenState extends State<SpacedReviewScreen> {
  late Future<List<WordProgress>> _future;
  List<WordProgress> _queue = const [];
  int _index = 0;
  bool _answered = false;
  bool _checking = false;
  bool _correct = false;
  late final String _sessionId;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sessionId = DateTime.now().microsecondsSinceEpoch.toString();
    _future = LearningStore.instance.loadReviewQueue();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _normalize(String value) => LearningEngine.normalizeAnswer(value);

  Future<void> _check() async {
    if (_answered || _checking || _index >= _queue.length) return;
    final word = _queue[_index];
    final answer = _controller.text.trim();
    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب إجابتك أولًا.')),
      );
      return;
    }
    final correct = _normalize(answer) == _normalize(word.term);
    setState(() => _checking = true);
    try {
      await LearningStore.instance.recordWord(
        lessonId: word.lessonId,
        term: word.term,
        meaning: word.meaning,
        correct: correct,
        eventId: 'spaced-review:$_sessionId:$_index',
      );
      if (!mounted) return;
      setState(() { _answered = true; _correct = correct; _checking = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _checking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ نتيجة المراجعة. حاول مرة أخرى.')),
      );
    }
  }

  void _next() {
    _controller.clear();
    setState(() { _index++; _answered = false; _correct = false; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('المراجعة المتباعدة')),
    body: FutureBuilder<List<WordProgress>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('تعذر تحميل قائمة المراجعة المحلية.'));
        }
        _queue = snapshot.data ?? const [];
        if (_queue.isEmpty) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.event_available_rounded, size: 58, color: Color(0xFF1D9B69)),
              const SizedBox(height: 14),
              const Text('لا توجد مفردات مستحقة للمراجعة الآن',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('قيّم تذكرك للمفردات داخل الدروس، وسيحدد التطبيق موعد المراجعة التالية تلقائيًا.',
                textAlign: TextAlign.center, style: TextStyle(height: 1.7)),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('العودة')),
            ]),
          ));
        }
        if (_index >= _queue.length) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.emoji_events_rounded, size: 58, color: Color(0xFFE0A92E)),
              const SizedBox(height: 14),
              const Text('اكتملت جلسة المراجعة!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('راجعت ${_queue.length} مفردة، وحُفظت مواعيد المراجعة الجديدة محليًا.'),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('تم')),
            ]),
          ));
        }
        final word = _queue[_index];
        return ListView(padding: const EdgeInsets.all(20), children: [
          LinearProgressIndicator(value: (_index + 1) / _queue.length, minHeight: 7),
          const SizedBox(height: 12),
          Text('المفردة ${_index + 1} من ${_queue.length}',
            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Card(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Icon(Icons.psychology_alt_rounded, size: 42, color: Color(0xFF334C82)),
              const SizedBox(height: 14),
              Text(word.meaning, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 18),
              TextField(controller: _controller, enabled: !_answered, autocorrect: false,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(border: OutlineInputBorder(),
                  labelText: 'اكتب الكلمة أو العبارة بالإنجليزية'),
                onSubmitted: (_) => _check()),
              if (_answered) ...[
                const SizedBox(height: 14),
                Container(width: double.infinity, padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _correct ? const Color(0xFFE7F7EC) : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12)),
                  child: Text(_correct ? 'إجابة صحيحة، أحسنت!' : 'الإجابة الصحيحة: ${word.term}',
                    style: TextStyle(fontWeight: FontWeight.w800,
                      color: _correct ? Colors.green.shade800 : Colors.red.shade800))),
                const SizedBox(height: 8),
                Text('الدقة السابقة: ${(word.accuracy * 100).round()}% · أخطاء سابقة: ${word.wrongCount}',
                  style: const TextStyle(color: Colors.grey)),
              ],
            ]),
          )),
          const SizedBox(height: 14),
          if (!_answered)
            FilledButton.icon(onPressed: _checking ? null : _check, icon: _checking ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded),
              label: const Text('تحقق من الإجابة'))
          else
            FilledButton(onPressed: _next,
              child: Text(_index == _queue.length - 1 ? 'إنهاء المراجعة' : 'المفردة التالية')),
        ]);
      },
    ),
  );
}
