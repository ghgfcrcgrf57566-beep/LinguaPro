import 'package:flutter/material.dart';

import '../learning/learning_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const tracks = <_Track>[
    _Track('تعلم الإنجليزية', 'English foundations', Icons.menu_book_rounded, Color(0xFFEAF0FF), LearningMode.general),
    _Track('القواعد', 'Grammar', Icons.account_tree_rounded, Color(0xFFFFF1E4), LearningMode.general),
    _Track('المفردات', 'Vocabulary & spaced review', Icons.translate_rounded, Color(0xFFE5F7EF), LearningMode.review),
    _Track('الاستماع والتحدث', 'Listening & Speaking', Icons.headphones_rounded, Color(0xFFF0EAFE), LearningMode.general),
    _Track('القراءة والكتابة', 'Reading & Writing', Icons.edit_note_rounded, Color(0xFFFFEAF0), LearningMode.general),
    _Track('الاختبارات والمراجعة', 'Quizzes & Review', Icons.quiz_rounded, Color(0xFFE5F4FA), LearningMode.review),
    _Track('أكاديمية الإنجليزية القانونية', 'Legal English Academy', Icons.gavel_rounded, Color(0xFFFFF3D9), LearningMode.legal),
    _Track('المعلّم الذكي', 'AI tutor · يتطلب ربط خدمة', Icons.auto_awesome_rounded, Color(0xFFEDEEFF), null),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          _BrandMark(),
          SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('أكاديمية الإنجليزية', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text('ENGLISH LEARNING ACADEMY', style: TextStyle(fontSize: 9, letterSpacing: 1, color: Color(0xFF7F899E))),
          ]),
        ]),
        actions: [
          IconButton(
            tooltip: 'الإعدادات',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
          children: [
            Text('ابدأ رحلتك نحو الطلاقة 👋', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 7),
            const Text('تعلّم الإنجليزية خطوة بخطوة، من الأساسيات إلى التخصص المهني والقانوني.', style: TextStyle(height: 1.8, fontSize: 13, color: Color(0xFF7F899E))),
            const SizedBox(height: 20),
            _WelcomeCard(onTap: () => _open(context, LearningMode.general)),
            const SizedBox(height: 26),
            const Text('مسارات التعلّم', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            const Text('دروس قصيرة، اختبارات، ومراجعة تساعد على تثبيت المفردات', style: TextStyle(fontSize: 12, color: Color(0xFF7F899E))),
            const SizedBox(height: 15),
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 700 ? 3 : 2;
              return GridView.builder(
                itemCount: tracks.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: columns == 3 ? 1.22 : 1.04,
                ),
                itemBuilder: (context, index) => _TrackCard(
                  track: tracks[index],
                  onTap: () {
                    final mode = tracks[index].mode;
                    if (mode == null) {
                      _notice(context, 'المعلّم الذكي يحتاج إلى إعداد خدمة آمنة على الخادم. الدروس المحلية والمراجعة تعمل دون هذه الخدمة.');
                    } else {
                      _open(context, mode);
                    }
                  },
                ),
              );
            }),
            const SizedBox(height: 20),
            const _LearningNote(),
            const SizedBox(height: 24),
            const Center(child: Text('LinguaPro · تعلم عام وتخصص قانوني', style: TextStyle(fontSize: 11, color: Color(0xFF9AA3B4)))),
          ],
        ),
      ),
    );
  }

  static void _open(BuildContext context, LearningMode mode) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => LearningScreen(mode: mode)));
  }

  static void _notice(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          gradient: const LinearGradient(colors: [Color(0xFF7188FF), Color(0xFF4962DD)]),
        ),
        alignment: Alignment.center,
        child: const Text('L+', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
      );
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(begin: Alignment.centerRight, end: Alignment.centerLeft, colors: [Color(0xFF172544), Color(0xFF334C82)]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.auto_awesome, color: Color(0xFFE9B95D), size: 17),
            SizedBox(width: 7),
            Text('خطة تعليمية عملية', style: TextStyle(color: Color(0xFFD5DDF0), fontSize: 12)),
          ]),
          const SizedBox(height: 13),
          const Text('كل يوم كلمة جديدة،\nوكل مراجعة تثبيت للذاكرة.', style: TextStyle(color: Colors.white, fontSize: 24, height: 1.45, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          const Text('ابدأ بالدروس، ثم اختبر نفسك وراجع الكلمات التي تحتاج إلى تدريب إضافي.', style: TextStyle(color: Color(0xFFD0D8E9), height: 1.8, fontSize: 12)),
          const SizedBox(height: 17),
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.arrow_back_rounded, size: 17),
            label: const Text('استكشف الدروس'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE9B95D), foregroundColor: const Color(0xFF182542)),
          ),
        ]),
      );
}

class _Track {
  const _Track(this.title, this.subtitle, this.icon, this.tint, this.mode);
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final LearningMode? mode;
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({required this.track, required this.onTap});
  final _Track track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(color: track.tint, borderRadius: BorderRadius.circular(13)),
                child: Icon(track.icon, color: const Color(0xFF455DAB)),
              ),
              const Spacer(),
              Text(track.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(track.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: Color(0xFF8A94A8))),
            ]),
          ),
        ),
      );
}

class _LearningNote extends StatelessWidget {
  const _LearningNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.psychology_alt_outlined, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          const Expanded(child: Text(
            'يتضمن الإصدار الحالي دروسًا محلية ومراجعة متباعدة أولية. الحسابات السحابية، المزامنة، الصوت التفاعلي ومدرس الذكاء الاصطناعي مراحل منفصلة لم تُفعّل بعد.',
            style: TextStyle(fontSize: 11, height: 1.8),
          )),
        ]),
      );
}
