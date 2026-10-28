import 'package:flutter/material.dart';
import '../../services/learning_engine.dart';

class MistakeReviewScreen extends StatefulWidget {
  const MistakeReviewScreen({super.key});
  @override
  State<MistakeReviewScreen> createState() => _MistakeReviewScreenState();
}

class _MistakeReviewScreenState extends State<MistakeReviewScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() { super.initState(); _future = LearningEngine.instance.mistakes(); }

  Future<void> _resolve(String eventId) async {
    await LearningEngine.instance.markMistakeResolved(eventId);
    if (!mounted) return;
    setState(() { _future = LearningEngine.instance.mistakes(); });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مراجعة الأخطاء')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('تعذر تحميل سجل الأخطاء المحلي.'));
        }
        final mistakes = snapshot.data ?? const <Map<String, dynamic>>[];
        if (mistakes.isEmpty) {
          return const Center(child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle_outline_rounded, size: 56, color: Color(0xFF1D9B69)),
            SizedBox(height: 12),
            Text('لا توجد أخطاء معلّقة للمراجعة.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text('عند الخطأ في اختبار محلي، سيُحفظ السؤال وإجابتك لتعود إليه لاحقًا.', textAlign: TextAlign.center),
          ]),
          ));
        }
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('أخطاء تحتاج إلى مراجعة: ${mistakes.length}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 12),
          for (final item in mistakes)
            Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['prompt']?.toString() ?? 'سؤال', style: const TextStyle(fontWeight: FontWeight.w800, height: 1.5)),
              const SizedBox(height: 8),
              Text('إجابتك: ${item['answer'] ?? '—'}'),
              if ((item['targetTerm']?.toString() ?? '').isNotEmpty) Text('الإجابة المستهدفة: ${item['targetTerm']}'),
              if ((item['targetMeaning']?.toString() ?? '').isNotEmpty) Text('توضيح: ${item['targetMeaning']}', style: const TextStyle(height: 1.6)),
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
                onPressed: () => _resolve(item['eventId']?.toString() ?? ''),
                icon: const Icon(Icons.done_rounded),
                label: const Text('علّمتُ الخطأ للمراجعة'),
              )),
            ]))),
        ]);
      },
    ),
  );
}
