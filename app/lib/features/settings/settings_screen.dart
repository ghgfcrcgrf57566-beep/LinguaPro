import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../services/app_preferences.dart';
import '../../services/learning_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<_Diagnostics>? _diagnostics;

  @override
  void initState() {
    super.initState();
    _diagnostics = _loadDiagnostics();
  }

  Future<_Diagnostics> _loadDiagnostics() async {
    Future<List<dynamic>> readLessons(String path) async {
      final decoded = jsonDecode(await rootBundle.loadString(path)) as Map<String, dynamic>;
      return decoded['lessons'] as List<dynamic>? ?? const [];
    }

    final generalLessons = <dynamic>[
      ...await readLessons('assets/lessons/english_a1.json'),
      ...await readLessons('assets/lessons/general_expansion.json'),
    ];
    final legalLessons = <dynamic>[
      ...await readLessons('assets/lessons/legal_english.json'),
      ...await readLessons('assets/lessons/legal_expansion.json'),
    ];
    final allIds = <String>[
      ...generalLessons.map((item) => (item as Map<String, dynamic>)['id'] as String? ?? ''),
      ...legalLessons.map((item) => (item as Map<String, dynamic>)['id'] as String? ?? ''),
    ];
    final progress = await LearningStore.instance.loadProgress();
    final completed = await LearningStore.instance.completedLessons();
    final quizzes = await LearningStore.instance.loadQuizResults();
    final uniqueIds = allIds.toSet();
    return _Diagnostics(
      generalLessons: generalLessons.length,
      legalLessons: legalLessons.length,
      duplicateIds: allIds.length - uniqueIds.length,
      invalidIds: allIds.where((id) => id.trim().isEmpty).length,
      trackedWords: progress.length,
      completedLessons: completed.length,
      quizAttempts: quizzes.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final preferences = AppPreferences.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _sectionTitle(context, 'المظهر وإمكانية القراءة'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ValueListenableBuilder<ThemeMode>(
                valueListenable: preferences.themeMode,
                builder: (context, mode, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('نمط العرض', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.settings_suggest_outlined), label: Text('النظام')),
                        ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('فاتح')),
                        ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('داكن')),
                      ],
                      selected: {mode},
                      onSelectionChanged: (selection) => preferences.setThemeMode(selection.first),
                    ),
                    const SizedBox(height: 18),
                    ValueListenableBuilder<double>(
                      valueListenable: preferences.textScale,
                      builder: (context, scale, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Expanded(child: Text('حجم النص')),
                            Text('${(scale * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ]),
                          Slider(
                            value: scale,
                            min: 0.85,
                            max: 1.3,
                            divisions: 9,
                            label: '${(scale * 100).round()}%',
                            onChanged: preferences.setTextScale,
                          ),
                          const Text('يُحفظ اختيارك على هذا الجهاز ويُطبّق على شاشات التطبيق.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          _sectionTitle(context, 'سلامة المحتوى والحفظ'),
          FutureBuilder<_Diagnostics>(
            future: _diagnostics,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())));
              }
              if (snapshot.hasError) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.error_outline, color: Colors.red),
                    title: const Text('تعذّر فحص ملفات الدروس'),
                    subtitle: Text('أعد تشغيل الفحص بعد التأكد من تثبيت نسخة التطبيق كاملة. التفاصيل: ${snapshot.error}'),
                    trailing: IconButton(
                      tooltip: 'إعادة الفحص',
                      icon: const Icon(Icons.refresh),
                      onPressed: () => setState(() => _diagnostics = _loadDiagnostics()),
                    ),
                  ),
                );
              }
              final d = snapshot.data!;
              final contentHealthy = d.generalLessons > 0 && d.legalLessons > 0 && d.duplicateIds == 0 && d.invalidIds == 0;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(contentHealthy ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                          color: contentHealthy ? Colors.green : Colors.orange),
                      const SizedBox(width: 9),
                      Expanded(child: Text(contentHealthy ? 'ملفات الدروس محمّلة' : 'توجد ملاحظات في المحتوى',
                          style: const TextStyle(fontWeight: FontWeight.w800))),
                      IconButton(
                        tooltip: 'إعادة الفحص',
                        onPressed: () => setState(() => _diagnostics = _loadDiagnostics()),
                        icon: const Icon(Icons.refresh),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    _diagnosticRow('دروس الإنجليزية العامة', d.generalLessons),
                    _diagnosticRow('دروس الإنجليزية القانونية', d.legalLessons),
                    _diagnosticRow('معرّفات مكررة', d.duplicateIds),
                    _diagnosticRow('معرّفات فارغة', d.invalidIds),
                    const Divider(height: 24),
                    _diagnosticRow('كلمات لها سجل تعلّم', d.trackedWords),
                    _diagnosticRow('دروس مكتملة', d.completedLessons),
                    _diagnosticRow('محاولات اختبارات محفوظة', d.quizAttempts),
                    const SizedBox(height: 10),
                    const Text(
                      'البيانات التعليمية تأتي من ملفات JSON المضمّنة في التطبيق، والتقدم محفوظ محليًا على الجهاز. لا توجد حاليًا قاعدة بيانات SQL أو مزامنة سحابية مهيأة؛ لذلك لا يُعرض اتصال غير موجود على أنه ناجح.',
                      style: TextStyle(fontSize: 12, height: 1.7, color: Colors.grey),
                    ),
                  ]),
                ),
              );
            },
          ),
          const SizedBox(height: 22),
          _sectionTitle(context, 'الخصوصية والتشغيل'),
          const Card(
            child: Column(children: [
              ListTile(
                leading: Icon(Icons.offline_bolt_outlined),
                title: Text('التعلّم دون إنترنت'),
                subtitle: Text('الدروس والاختبارات والمراجعة الأساسية تعمل محليًا بعد تثبيت التطبيق.'),
              ),
              Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.cloud_off_outlined),
                title: Text('الخدمات السحابية'),
                subtitle: Text('الحساب والمزامنة والمعلّم الذكي غير مفعّلة في هذا الإصدار. لا تُدخل مفاتيح سرية داخل التطبيق.'),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          Center(child: Text('LinguaPro · الإصدار التعليمي', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      );

  Widget _diagnosticRow(String label, int value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [Expanded(child: Text(label)), Text('$value', style: const TextStyle(fontWeight: FontWeight.w800))]),
      );
}

class _Diagnostics {
  const _Diagnostics({
    required this.generalLessons,
    required this.legalLessons,
    required this.duplicateIds,
    required this.invalidIds,
    required this.trackedWords,
    required this.completedLessons,
    required this.quizAttempts,
  });

  final int generalLessons;
  final int legalLessons;
  final int duplicateIds;
  final int invalidIds;
  final int trackedWords;
  final int completedLessons;
  final int quizAttempts;
}
