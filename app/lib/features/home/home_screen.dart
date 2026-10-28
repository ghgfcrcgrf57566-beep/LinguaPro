import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const tracks = <_Track>[
    _Track('تعلم الإنجليزية', 'English foundations', Icons.menu_book_rounded, Color(0xFFEAF0FF)),
    _Track('القواعد', 'Grammar', Icons.account_tree_rounded, Color(0xFFFFF1E4)),
    _Track('المفردات', 'Vocabulary', Icons.translate_rounded, Color(0xFFE5F7EF)),
    _Track('الاستماع والتحدث', 'Listening & Speaking', Icons.headphones_rounded, Color(0xFFF0EAFE)),
    _Track('القراءة والكتابة', 'Reading & Writing', Icons.edit_note_rounded, Color(0xFFFFEAF0)),
    _Track('الاختبارات', 'Quizzes', Icons.quiz_rounded, Color(0xFFE5F4FA)),
    _Track('أكاديمية الإنجليزية القانونية', 'Legal English Academy', Icons.gavel_rounded, Color(0xFFFFF3D9)),
    _Track('المعلّم الذكي', 'AI tutor · إعداد الخدمة مطلوب', Icons.auto_awesome_rounded, Color(0xFFEDEEFF)),
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
            onPressed: () => _notice(context, 'ستُضاف إعدادات الحساب واللغة والمظهر في مرحلة لاحقة.'),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
          children: [
            const Text('ابدأ رحلتك نحو الطلاقة 👋', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: Color(0xFF1D2941))),
            const SizedBox(height: 7),
            const Text('تعلّم الإنجليزية خطوة بخطوة، من الأساسيات إلى التخصص المهني.', style: TextStyle(height: 1.8, fontSize: 13, color: Color(0xFF7F899E))),
            const SizedBox(height: 20),
            const _WelcomeCard(),
            const SizedBox(height: 26),
            const Text('مسارات التعلّم', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            const Text('اختر المهارة التي تريد تطويرها', style: TextStyle(fontSize: 12, color: Color(0xFF7F899E))),
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
                  onTap: () => _notice(context, 'تم تجهيز مدخل هذا القسم. ستُربط الدروس والبيانات بالخادم السحابي في المرحلة التالية.'),
                ),
              );
            }),
            const SizedBox(height: 20),
            const _ArchitectureNote(),
            const SizedBox(height: 24),
            const Center(child: Text('LinguaPro · إصدار أولي قيد التطوير', style: TextStyle(fontSize: 11, color: Color(0xFF9AA3B4)))),
          ],
        ),
      ),
    );
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
  const _WelcomeCard();

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
            Text('خطتك التعليمية تبدأ هنا', style: TextStyle(color: Color(0xFFD5DDF0), fontSize: 12)),
          ]),
          const SizedBox(height: 13),
          const Text('كل يوم كلمة جديدة،\nوكل درس خطوة للأمام.', style: TextStyle(color: Colors.white, fontSize: 24, height: 1.45, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          const Text('ستتوسع هذه المساحة بالدروس والاختبارات المتصلة بالمحتوى السحابي.', style: TextStyle(color: Color(0xFFD0D8E9), height: 1.8, fontSize: 12)),
          const SizedBox(height: 17),
          FilledButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيبدأ أول درس عند إضافة مصدر المحتوى في المرحلة الثانية.'))),
            icon: const Icon(Icons.arrow_back_rounded, size: 17),
            label: const Text('استكشف الدروس'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE9B95D), foregroundColor: const Color(0xFF182542)),
          ),
        ]),
      );
}

class _Track {
  const _Track(this.title, this.subtitle, this.icon, this.tint);
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
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

class _ArchitectureNote extends StatelessWidget {
  const _ArchitectureNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFEFF3FF), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFDCE4FF))),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.cloud_outlined, color: Color(0xFF4968E8)),
          SizedBox(width: 10),
          Expanded(child: Text(
            'البنية السحابية: سيُدار الكود والمحتوى عبر GitHub، وستُقدَّم البيانات التشغيلية من API وقاعدة بيانات سحابية بعد إعدادها. هذه النسخة لا تدّعي أن الخادم متصل بعد.',
            style: TextStyle(color: Color(0xFF465675), fontSize: 11, height: 1.8),
          )),
        ]),
      );
}
