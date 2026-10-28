import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../models/learning_lesson.dart';
import '../../services/learning_engine.dart';
import '../../services/learning_store.dart';
import '../learning/learning_screen.dart';
import '../learning/exercise_session_screen.dart';
import '../settings/settings_screen.dart';

class LearningMapScreen extends StatefulWidget {
  const LearningMapScreen({super.key});
  @override
  State<LearningMapScreen> createState() => _LearningMapScreenState();
}
class _LearningMapScreenState extends State<LearningMapScreen> {
  bool legal = false;
  int tab = 0, xp = 0, goal = 20, today = 0, streak = 0, attemptLimit = 0;
  int? attemptsLeft;
  Map<String, int> challenges = <String, int>{};
  List<String> badges = <String>[];
  Set<String> completed = <String>{};
  Map<String, QuizResult> bestScores = <String, QuizResult>{};
  late Future<List<LearningLesson>> lessonsFuture;
  @override
  void initState() { super.initState(); lessonsFuture = loadLessons(); refresh(); }
  Future<List<LearningLesson>> loadLessons() async {
    final paths = legal ? ['assets/lessons/legal_english.json','assets/lessons/legal_expansion.json'] : ['assets/lessons/english_a1.json','assets/lessons/general_expansion.json'];
    final out = <LearningLesson>[];
    for (final path in paths) {
      final data = jsonDecode(await rootBundle.loadString(path)) as Map<String,dynamic>;
      out.addAll((data['lessons'] as List<dynamic>? ?? const []).map((e) => LearningLesson.fromJson(Map<String,dynamic>.from(e as Map))));
    }
    return out;
  }
  Future<void> refresh() async {
    final e = LearningEngine.instance;
    final v = await Future.wait<Object>([LearningStore.instance.totalXp(),e.dailyGoal(),e.todayXp(),e.streak(),LearningStore.instance.completedLessons(),e.challengeSummary(),e.unlockedBadges(),e.dailyAttemptLimit(),e.attemptsRemaining(),LearningStore.instance.bestQuizResults()]);
    if (!mounted) return;
    setState(() { xp=v[0] as int; goal=v[1] as int; today=v[2] as int; streak=v[3] as int; completed=v[4] as Set<String>; challenges=v[5] as Map<String,int>; badges=v[6] as List<String>; attemptLimit=v[7] as int; attemptsLeft=v[8] as int?; bestScores=v[9] as Map<String, QuizResult>; });
  }
  void switchTrack(bool value) { if (legal == value) return; setState(() { legal=value; lessonsFuture=loadLessons(); }); }
  Future<void> changeGoal() async {
    final n = await showModalBottomSheet<int>(context:context,showDragHandle:true,builder:(context)=>SafeArea(child:Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('اختر هدفك اليومي',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:8),const Text('هدف صغير ومستمر أفضل من جلسة طويلة متقطعة.'),const SizedBox(height:12),
      Wrap(spacing:8,runSpacing:8,children:[for(final value in [10,15,20,30,40,50,75,100]) ChoiceChip(label:Text('$value XP'),selected:value==goal,onSelected:(_)=>Navigator.pop(context,value))])
    ]))));
    if(n==null)return; await LearningEngine.instance.setDailyGoal(n); await refresh();
  }

  Future<void> changeAttempts() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('نظام المحاولات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('اختر عدد المحاولات اليومية. لا يؤثر ذلك في حفظ تقدمك.'),
            const SizedBox(height: 12),
            for (final value in [0, 3, 5, 10])
              ListTile(
                leading: Icon(value == 0 ? Icons.all_inclusive_rounded : Icons.favorite_rounded),
                title: Text(value == 0 ? 'غير محدود' : '$value محاولات يوميًا'),
                trailing: attemptLimit == value ? const Icon(Icons.check_circle, color: Color(0xFF1D9B69)) : null,
                onTap: () => Navigator.pop(context, value),
              ),
          ]),
        ),
      ),
    );
    if (selected == null) return;
    await LearningEngine.instance.setDailyAttemptLimit(selected);
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    if(tab==1) return Scaffold(appBar:AppBar(title:const Text('المراجعة الذكية')),body:const LearningScreen(mode:LearningMode.review),bottomNavigationBar:nav());
    if(tab==2) return Scaffold(appBar:AppBar(title:const Text('الإعدادات')),body:const SettingsScreen(),bottomNavigationBar:nav());
    return Scaffold(
      appBar:AppBar(title:const Row(children:[_Mark(),SizedBox(width:9),Text('LinguaPro',style:TextStyle(fontWeight:FontWeight.w900))]),actions:[
        _Pill(icon:Icons.local_fire_department_rounded,label:'$streak',color:const Color(0xFFF08B36)),const SizedBox(width:8),_Pill(icon:Icons.bolt_rounded,label:'$xp',color:const Color(0xFFE8AC24)),const SizedBox(width:12)
      ]),
      body:SafeArea(child:FutureBuilder<List<LearningLesson>>(future:lessonsFuture,builder:(context,snapshot){
        if(snapshot.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
        if(snapshot.hasError)return Center(child:Text('تعذّر تحميل الدروس: '+snapshot.error.toString()));
        final lessons=snapshot.data??const <LearningLesson>[];
        final grouped=<String,List<LearningLesson>>{};
        for(final lesson in lessons){grouped.putIfAbsent(lesson.level,()=>[]).add(lesson);}
        final order=['A1','A2','B1','B2','C1','C2','LEGAL'];
        final levels=grouped.keys.toList()..sort((a,b)=>order.indexOf(a.toUpperCase()).compareTo(order.indexOf(b.toUpperCase())));
        final orderedLessons = <LearningLesson>[for (final level in levels) ...grouped[level]!];
        final done=lessons.where((l)=>completed.contains(l.id)).length;
        return ListView(padding:const EdgeInsets.fromLTRB(16,8,16,28),children:[
          Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:const Color(0xFF176B4D),borderRadius:BorderRadius.circular(24)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[const Expanded(child:Text('رحلتك نحو الطلاقة',style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900))),Text(legal?'LEGAL':'GENERAL',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900))]),
            const SizedBox(height:7),Text(legal?'تدرّب على لغة المحاكم والعقود والمرافعات.':'دروس قصيرة ومحادثات وتمارين تبني مهاراتك خطوة بخطوة.',style:const TextStyle(color:Color(0xFFE0F4EA),height:1.6)),
            const SizedBox(height:16),Row(children:[
              Expanded(child:InkWell(onTap:changeGoal,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('الهدف اليومي $today/$goal XP  ✎',style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w800)),const SizedBox(height:8),
                ClipRRect(borderRadius:BorderRadius.circular(8),child:LinearProgressIndicator(value:goal==0?0:(today/goal).clamp(0.0,1.0),minHeight:8,backgroundColor:Colors.white24,color:const Color(0xFFFFD36B)))
              ]))),const SizedBox(width:14),Container(width:1,height:42,color:Colors.white24),const SizedBox(width:14),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(done.toString()+' / '+lessons.length.toString()+' درس',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:15)),const Text('تقدم المسار',style:TextStyle(color:Color(0xFFE0F4EA),fontSize:12))]))
            ])
          ])),
          const SizedBox(height:16),
          Container(padding:const EdgeInsets.all(5),decoration:BoxDecoration(color:const Color(0xFFEAF0EC),borderRadius:BorderRadius.circular(16)),child:Row(children:[
            Expanded(child:_TrackButton(label:'الإنجليزية العامة',selected:!legal,onTap:()=>switchTrack(false))),
            Expanded(child:_TrackButton(label:'الإنجليزية القانونية',selected:legal,onTap:()=>switchTrack(true)))
          ])),
          const SizedBox(height:14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.flag_rounded, color: Color(0xFF1D9B69)),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('تحدياتك', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                  TextButton.icon(onPressed: changeAttempts, icon: const Icon(Icons.favorite_border_rounded, size: 17), label: Text(attemptLimit == 0 ? 'محاولات غير محدودة' : 'المتبقي ${attemptsLeft ?? 0}')),
                ]),
                const SizedBox(height: 8),
                _ChallengeLine(label: 'تحدي اليوم: أكمل درسًا', current: challenges['dailyLessons'] ?? 0, target: challenges['dailyTarget'] ?? 1),
                const SizedBox(height: 10),
                _ChallengeLine(label: 'تحدي الأسبوع: خمسة دروس', current: challenges['weeklyLessons'] ?? 0, target: challenges['weeklyTarget'] ?? 5),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExerciseSessionScreen())),
                    icon: const Icon(Icons.extension_rounded),
                    label: const Text('جرّب أنواع التمارين التفاعلية'),
                  ),
                ),
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('شاراتك', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [for (final badge in badges) Chip(avatar: const Icon(Icons.workspace_premium_rounded, size: 17), label: Text(badge))]),
                ],
              ]),
            ),
          ),
          const SizedBox(height:22),Row(children:[const Expanded(child:Text('خريطة التعلّم',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900))),Text(lessons.length.toString()+' درس',style:const TextStyle(color:Color(0xFF728078),fontWeight:FontWeight.w700))]),
          const SizedBox(height:5),const Text('أكمل الدروس بالترتيب لفتح الخطوة التالية.',style:TextStyle(color:Color(0xFF728078),fontSize:12)),const SizedBox(height:18),
          for(final level in levels)...[
            _Level(level:level,count:grouped[level]!.length),const SizedBox(height:12),
            for(final lesson in grouped[level]!)...[
              _LessonNode(index:orderedLessons.indexOf(lesson),lesson:lesson,done:completed.contains(lesson.id),unlocked:orderedLessons.indexOf(lesson)==0||(completed.contains(orderedLessons[orderedLessons.indexOf(lesson)-1].id)&&bestScores[orderedLessons[orderedLessons.indexOf(lesson)-1].id]!=null&&bestScores[orderedLessons[orderedLessons.indexOf(lesson)-1].id]!.percentage>=0.7),onTap:(){
                Navigator.of(context).push(MaterialPageRoute(builder:(_)=>LessonScreen(lesson:lesson))).then((_)=>refresh());
              }),
              const SizedBox(height:4)
            ],const SizedBox(height:20)
          ],
          const Center(child:Text('خطوة صغيرة كل يوم تصنع فرقًا كبيرًا.',style:TextStyle(color:Color(0xFF7A897F),fontSize:12)))
        ]);
      })),
      bottomNavigationBar:nav(),
    );
  }
  Widget nav()=>NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const[
    NavigationDestination(icon:Icon(Icons.route_rounded),label:'التعلّم'),NavigationDestination(icon:Icon(Icons.refresh_rounded),label:'المراجعة'),NavigationDestination(icon:Icon(Icons.tune_rounded),label:'الإعدادات')
  ]);
}
class _ChallengeLine extends StatelessWidget {
  const _ChallengeLine({required this.label, required this.current, required this.target});
  final String label;
  final int current;
  final int target;
  @override
  Widget build(BuildContext context) {
    final progress = target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))), Text('$current/$target', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF176B4D)))]),
      const SizedBox(height: 5),
      ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: const Color(0xFFE5EEE8), color: const Color(0xFF55B879))),
    ]);
  }
}

class _Mark extends StatelessWidget { const _Mark(); @override Widget build(BuildContext context)=>Container(width:36,height:36,decoration:BoxDecoration(color:const Color(0xFF1D9B69),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.auto_stories_rounded,color:Colors.white,size:22));}
class _Pill extends StatelessWidget {
  const _Pill({required this.icon,required this.label,required this.color}); final IconData icon;final String label;final Color color;
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:7),decoration:BoxDecoration(color:color.withValues(alpha:.12),borderRadius:BorderRadius.circular(18)),child:Row(children:[Icon(icon,size:18,color:color),const SizedBox(width:4),Text(label,style:TextStyle(fontWeight:FontWeight.w900,color:color))]));
}
class _TrackButton extends StatelessWidget {
  const _TrackButton({required this.label,required this.selected,required this.onTap});final String label;final bool selected;final VoidCallback onTap;
  @override Widget build(BuildContext context)=>GestureDetector(onTap:onTap,child:AnimatedContainer(duration:const Duration(milliseconds:180),padding:const EdgeInsets.symmetric(vertical:12,horizontal:6),decoration:BoxDecoration(color:selected?Colors.white:Colors.transparent,borderRadius:BorderRadius.circular(12),boxShadow:selected?const[BoxShadow(color:Color(0x12000000),blurRadius:5,offset:Offset(0,2))]:null),child:Text(label,textAlign:TextAlign.center,style:TextStyle(fontSize:12,fontWeight:FontWeight.w900,color:selected?const Color(0xFF176B4D):const Color(0xFF66736B)))));
}
class _Level extends StatelessWidget {
  const _Level({required this.level,required this.count});final String level;final int count;
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:14),decoration:BoxDecoration(color:const Color(0xFF176B4D),borderRadius:BorderRadius.circular(16)),child:Row(children:[
    Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.16),borderRadius:BorderRadius.circular(9)),child:Text(level.toUpperCase(),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900))),
    const SizedBox(width:10),Expanded(child:Text(level=='LEGAL'?'المسار القانوني':'المستوى '+level,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800))),Text('$count درس',style:const TextStyle(color:Color(0xFFD8F2E4),fontSize:12))
  ]));
}
class _LessonNode extends StatelessWidget {
  const _LessonNode({required this.index,required this.lesson,required this.done,required this.unlocked,required this.onTap});
  final int index;final LearningLesson lesson;final bool done,unlocked;final VoidCallback onTap;
  @override Widget build(BuildContext context){
    final color=done?const Color(0xFF1D9B69):unlocked?const Color(0xFF55B879):const Color(0xFFB8C3BC);
    return Column(children:[
      Align(alignment:index.isEven?Alignment.center:Alignment.centerRight,child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:310),child:InkWell(
        onTap:unlocked?onTap:()=>ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('أكمل الدرس السابق واحصل على 70% على الأقل لفتح هذه الخطوة.'))),
        borderRadius:BorderRadius.circular(22),child:Row(mainAxisSize:MainAxisSize.min,children:[
          Container(width:66,height:66,decoration:BoxDecoration(color:color,shape:BoxShape.circle,border:Border.all(color:color.withValues(alpha:.45),width:5),boxShadow:[BoxShadow(color:color.withValues(alpha:.20),blurRadius:0,offset:const Offset(0,5))]),child:Icon(done?Icons.check_rounded:unlocked?(lesson.isLegal?Icons.gavel_rounded:Icons.star_rounded):Icons.lock_rounded,color:Colors.white,size:29)),
          const SizedBox(width:12),Flexible(child:Container(padding:const EdgeInsets.symmetric(horizontal:13,vertical:12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15),border:Border.all(color:const Color(0xFFE2EAE4))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(lesson.title,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w900,color:Color(0xFF27362D))),
            const SizedBox(height:4),Text(lesson.vocabulary.length.toString()+' مفردات · '+lesson.quiz.length.toString()+' أسئلة',style:const TextStyle(fontSize:11,color:Color(0xFF7A897F))),
            if(done)const Text('مكتمل ✓',style:TextStyle(fontSize:11,fontWeight:FontWeight.w800,color:Color(0xFF1D9B69)))
          ])))
        ])
      ))),
      Container(width:5,height:18,decoration:BoxDecoration(color:done?const Color(0xFF1D9B69):const Color(0xFFDCE6DF),borderRadius:BorderRadius.circular(5)))
    ]);
  }
}
