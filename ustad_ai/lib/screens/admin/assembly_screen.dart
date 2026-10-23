// lib/screens/admin/assembly_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/whatsapp_service.dart';
import '../../widgets/network_banner.dart';

class AssemblyScreen extends StatefulWidget {
  const AssemblyScreen({super.key});

  @override
  State<AssemblyScreen> createState() => _AssemblyScreenState();
}

class _AssemblyScreenState extends State<AssemblyScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlaying = false;
  int _shuffleCounter = 0;

  // ── Dynamic Content Banks ──────────────────────────────────────────────────
  static const List<Map<String, String>> _morningChitChats = [
    {
      'topic': 'The Power of One Good Deed',
      'chitChatUrdu': 'پیارے بچو! السلام علیکم۔ کتابیں کھولنے سے پہلے ایک فوری بات چیت: آج صبح اسکول آنے سے پہلے آپ نے اپنے والدین کے لیے کیا اچھا کام کیا؟ چہروں پر مسکراہٹ لائیں اور بتائیں!',
      'icebreaker': 'Quick 2-min share: What is one kind act you did before leaving home this morning?',
    },
    {
      'topic': 'Dream Big for Pakistan',
      'chitChatUrdu': 'السلام علیکم کلاس! اگر آپ کو پاکستان کے لیے ایک نئی ایجاد کرنے کا موقع ملے، تو وہ کیا ہوگی؟ دو منٹ سوچیں اور اپنے ساتھ والے ساتھی سے شیئر کریں۔',
      'icebreaker': 'Turn & Talk: If you could invent one machine to help our city or school, what would it be?',
    },
    {
      'topic': 'The Secret of True Champions',
      'chitChatUrdu': 'صبح بخیر ہونہار طلباء! دنیا کا سب سے بڑا چیمپئن وہ نہیں جو کبھی گرتا نہیں، بلکہ وہ ہے جو ہر بار گر کر دوبارہ اٹھتا ہے۔ آج کون سا نیا سوال پوچھیں گے آپ؟',
      'icebreaker': 'Classroom Energy Check: What is one tough math or science question you will master today?',
    },
    {
      'topic': 'Gratitude & Smiling Faces',
      'chitChatUrdu': 'پیارے بچو! رسول اللہ ﷺ نے فرمایا کہ مسکرانا بھی صدقہ ہے۔ آج کلاس میں جس سے بھی نظریں ملیں، دل سے مسکرا کر سلام کریں۔ کس نے سب سے خوبصورت مسکراہٹ سجائی؟',
      'icebreaker': 'Warm-Up: Turn to your neighbor, give them a warm Salam and share one thing you are grateful for today.',
    },
    {
      'topic': 'Teamwork & Helping Hands',
      'chitChatUrdu': 'السلام علیکم! ایک اکیلی انگلی کچھ نہیں اٹھا سکتی، لیکن پانچ انگلیاں مل کر مٹھی بن جاتی ہیں جو ہر مشکل پر قابو پا سکتی ہے۔ آج ہم کلاس میں ایک ٹیم کی طرح پڑھیں گے!',
      'icebreaker': 'Pair Challenge: Pick a study buddy today and pledge to help each other understand today\'s hardest lesson.',
    },
    {
      'topic': 'Curiosity: The Key to Genius',
      'chitChatUrdu': 'صبح بخیر ننھے سائنس دانو! البرونی اور ابن الہیثم اس لیے عظیم بنے کیونکہ وہ ہر چیز کو غور سے دیکھتے تھے۔ آج کلاس میں کم از کم ایک نیا "کیوں" ضرور پوچھیں!',
      'icebreaker': 'Curiosity Starter: What is something natural you saw on the way to school that made you wonder how it works?',
    },
    {
      'topic': 'Honesty: The Golden Badge',
      'chitChatUrdu': 'پیارے بچو! سچ بولنا بہادری کی سب سے بڑی علامت ہے۔ قائدِ اعظم محمد علی جناح کی کامیابی کا راز ان کی دیانت داری تھی۔ کیا ہم سب بھی قائد کے سچے سپاہی ہیں؟',
      'icebreaker': 'Quick Discussion: Why does telling the truth give our hearts instant peace and courage?',
    },
  ];

  static const List<Map<String, String>> _hadiths = [
    {
      'arabic': 'طَلَبُ الْعِلْمِ فَرِيضَةٌ عَلَى كُلِّ مُسْلِمٍ',
      'urdu': 'علم حاصل کرنا ہر مسلمان پر فرض ہے۔ (سنن ابن ماجہ)',
      'lesson': 'Seeking knowledge is a divine duty for every learner, inspiring our study today.',
    },
    {
      'arabic': 'إِنَّ اللَّهَ يُحِبُّ إِذَا عَمِلَ أَحَدُكُمْ عَمَلًا أَنْ يُتْقِنَهُ',
      'urdu': 'اللہ تعالیٰ اس بات کو پسند فرماتا ہے کہ جب تم میں سے کوئی کام کرے تو اسے مہارت اور خوبصورتی سے مکمل کرے۔ (طبرانی)',
      'lesson': 'Excellence and precision in classwork brings Allah\'s blessings and success.',
    },
    {
      'arabic': 'الْبِرُّ حُسْنُ الْخُلُقِ',
      'urdu': 'نیکی اچھے اخلاق اور عمدہ کردار کا نام ہے۔ (صحیح مسلم)',
      'lesson': 'Noble character, polite speech, and kindness to peers is the greatest virtue.',
    },
    {
      'arabic': 'مَنْ لَا يَرْحَمُ لَا يُرْحَمُ',
      'urdu': 'جو دوسروں پر رحم نہیں کرتا اس پر رحم نہیں کیا جاتا۔ (صحیح بخاری)',
      'lesson': 'Showing mercy, patience, and love to younger schoolmates and classmates.',
    },
    {
      'arabic': 'الطُّهُورُ شَطْرُ الْإِيمَانِ',
      'urdu': 'صفائی اور پاکیزگی نصف ایمان ہے۔ (صحیح مسلم)',
      'lesson': 'Keep your desk, classroom floor, and school uniform spotlessly clean today.',
    },
    {
      'arabic': 'الْمُؤْمِنُ الْقَوِيُّ خَيْرٌ وَأَحَبُّ إِلَى اللَّهِ مِنَ الْمُؤْمِنِ الضَّعِيفِ',
      'urdu': 'طاقتور اور باہمت مومن اللہ کو کمزور سے زیادہ محبوب ہے۔ (صحیح مسلم)',
      'lesson': 'Be mentally strong, intellectually active, and physically healthy.',
    },
    {
      'arabic': 'تَبَسُّمُكَ فِي وَجْهِ أَخِيكَ لَكَ صَدَقَةٌ',
      'urdu': 'اپنے بھائی کے سامنے تمہارا مسکرا کر ملنا صدقہ ہے۔ (جامع ترمذی)',
      'lesson': 'A cheerful face spreads joy and peace throughout the entire classroom.',
    },
  ];

  static const List<Map<String, String>> _scienceSparks = [
    {
      'fact': 'Did you know? Honey never spoils! Archaeologists have found 3,000-year-old pots of preserved honey in Egyptian tombs that are still perfectly edible!',
      'factUrdu': 'کیا آپ جانتے ہیں؟ شہد کبھی خراب نہیں ہوتا! مصر کے اہرام میں تین ہزار سال پرانا شہد بھی کھانے کے قابل حالت میں پایا گیا۔',
    },
    {
      'fact': 'Did you know? Trees in a forest communicate underground using complex fungal networks called mycorrhizae, sharing water and warning of insect attacks!',
      'factUrdu': 'کیا آپ جانتے ہیں؟ جنگل کے درخت زمین کے نیچے فنگس کے جال کے ذریعے ایک دوسرے کو پانی پہنچاتے اور خطرے سے خبردار کرتے ہیں!',
    },
    {
      'fact': 'Did you know? Your brain generates about 20 watts of electrical power while awake — enough to power a small LED light bulb!',
      'factUrdu': 'کیا آپ جانتے ہیں؟ انسان کا دماغ جاگتے ہوئے اتنی برقی توانائی خارج کرتا ہے جس سے ایک چھوٹا ایل ای ڈی بلب روشن کیا جا سکتا ہے!',
    },
    {
      'fact': 'Did you know? A teaspoon of a neutron star would weigh about 6 billion tons on Earth due to extreme gravitational density!',
      'factUrdu': 'کیا آپ جانتے ہیں؟ نیوٹران ستارے کا صرف ایک چمچ مادہ زمین پر 6 ارب ٹن وزنی ہوگا!',
    },
    {
      'fact': 'Did you know? Raindrops aren\'t shaped like tears! As they fall through the atmosphere, air resistance flattens them into the shape of hamburger buns!',
      'factUrdu': 'کیا آپ جانتے ہیں؟ بارش کے قطرے آنسو کی شکل کے نہیں بلکہ ہوا کی رگڑ سے گول برگر بن جیسے چپٹے ہو جاتے ہیں!',
    },
    {
      'fact': 'Did you know? The human eye can distinguish approximately 10 million distinct colors, working like a 576-megapixel biological camera!',
      'factUrdu': 'کیا آپ جانتے ہیں؟ انسانی آنکھ تقریباً ایک کروڑ مختلف رنگ پہچان سکتی ہے اور 576 میگا پکسل کے کیمرے کی طرح کام کرتی ہے!',
    },
    {
      'fact': 'Did you know? Octopuses have three hearts and blue blood because it uses copper instead of iron to carry oxygen in cold deep ocean waters!',
      'factUrdu': 'کیا آپ جانتے ہیں؟ آکٹوپس کے تین دل اور نیلا خون ہوتا ہے کیونکہ وہ لوہے کے بجائے تانبے سے آکسیجن منتقل کرتا ہے!',
    },
  ];

  static const List<String> _dailyChallenges = [
    '🎯 Challenge: No waste paper on the floor — make your classroom the cleanest in Sublime Grammar School today!',
    '🎯 Challenge: Say "JazakAllah Khair" to the school peon and van driver with a sincere smile.',
    '🎯 Challenge: Help at least one classmate solve a difficult problem before the bell rings.',
    '🎯 Challenge: Keep your posture straight and raise your hand with confidence for every question.',
    '🎯 Challenge: Learn 3 new English & Urdu vocabulary words and use them in full sentences today.',
    '🎯 Challenge: Greet your teachers at the classroom door before sitting down.',
    '🎯 Challenge: Finish your homework before evening prayer so you have peaceful family time.',
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  void _initTts() {
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isPlaying = false);
    });
    _flutterTts.setErrorHandler((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  int _getDynamicIndex(String teacherName, int bankSize) {
    final now = DateTime.now();
    // Unique seed combining Teacher identity + Day of Year + Shuffle Counter
    final teacherHash = teacherName.toLowerCase().hashCode.abs();
    final daySeed = now.year * 365 + now.month * 31 + now.day;
    return (teacherHash + daySeed + _shuffleCounter * 3) % bankSize;
  }

  Future<void> _speakMorningTalk(Map<String, dynamic> bundle) async {
    if (_isPlaying) {
      await _flutterTts.stop();
      setState(() => _isPlaying = false);
      return;
    }

    setState(() => _isPlaying = true);
    await _flutterTts.setLanguage('ur-PK');
    await _flutterTts.setSpeechRate(0.48);

    final chitChat = bundle['chitChat']['chitChatUrdu'] as String;
    final hadithUrdu = bundle['hadith']['urdu'] as String;
    final science = bundle['science']['factUrdu'] as String;

    final textToSpeak =
        'السلام علیکم پیارے بچو! کلاس مارننگ ٹاک میں خوش آمدید۔ $chitChat۔ حدیثِ مبارکہ: $hadithUrdu۔ معلوماتی نکتہ: $science۔ شکریہ!';
    await _flutterTts.speak(textToSpeak);
  }

  Future<void> _shareMorningTalkWhatsApp(Map<String, dynamic> bundle, String teacherName) async {
    final message =
        '🌅 سبلائم گرامر اسکول — روزانہ کلاس گفتگو و حدیث\n'
        'استاد: $teacherName • تاریخ: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}\n\n'
        '💬 صبح کی باہمی گفتگو:\n${bundle['chitChat']['chitChatUrdu']}\n\n'
        '📖 حدیثِ مبارکہ:\n${bundle['hadith']['arabic']}\n${bundle['hadith']['urdu']}\n\n'
        '🔬 سائنسی نکتہ:\n${bundle['science']['factUrdu']}\n\n'
        '🎯 آج کا کلاس چیلنج:\n${bundle['challenge']}\n\n'
        'آپ کا تعلیمی دن مبارک اور پرنور ہو!\nانتظامیہ سبلائم گرامر اسکول';

    await WhatsAppService.showShareDialog(
      context: context,
      title: 'Share Morning Talk',
      subtitle: 'Conducted by: $teacherName',
      message: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final teacherName = auth.user?.name ?? 'Teacher';

    final chitChatIdx = _getDynamicIndex(teacherName, _morningChitChats.length);
    final hadithIdx = _getDynamicIndex('$teacherName-hadith', _hadiths.length);
    final scienceIdx = _getDynamicIndex('$teacherName-science', _scienceSparks.length);
    final challengeIdx = _getDynamicIndex('$teacherName-challenge', _dailyChallenges.length);

    final chitChat = _morningChitChats[chitChatIdx];
    final hadith = _hadiths[hadithIdx];
    final science = _scienceSparks[scienceIdx];
    final challenge = _dailyChallenges[challengeIdx];

    final currentBundle = {
      'chitChat': chitChat,
      'hadith': hadith,
      'science': science,
      'challenge': challenge,
    };

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('🌅 Class Morning Talk & Hadith'),
        backgroundColor: AppTheme.navyBlue,
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle_rounded),
            tooltip: 'New Chit-Chat Topic / نیا موضوع',
            onPressed: () {
              setState(() {
                _shuffleCounter++;
                if (_isPlaying) {
                  _flutterTts.stop();
                  _isPlaying = false;
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🎲 Fresh morning chit-chat & Hadith topic loaded!'), duration: Duration(seconds: 1)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.greenAccent),
            tooltip: 'Share via WhatsApp',
            onPressed: () => _shareMorningTalkWhatsApp(currentBundle, teacherName),
          ),
        ],
      ),
      body: Column(
        children: [
          const NetworkBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Hero Speaker Card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: AppTheme.navyGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Morning Talk • $teacherName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                                  const SizedBox(height: 2),
                                  const Text('Daily 3-min Classroom Entry Warm-Up', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                              CircleAvatar(
                                backgroundColor: Colors.white24,
                                child: IconButton(
                                  icon: Icon(_isPlaying ? Icons.stop : Icons.volume_up, color: Colors.white),
                                  onPressed: () => _speakMorningTalk(currentBundle),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _speakMorningTalk(currentBundle),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isPlaying ? Colors.red : AppTheme.accentGold,
                                foregroundColor: _isPlaying ? Colors.white : Colors.black87,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: Icon(_isPlaying ? Icons.stop_circle : Icons.campaign),
                              label: Text(
                                _isPlaying ? 'Stop Spoken Audio' : '🎙️ Play Morning Chit-Chat over Speaker',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 1. Morning Chit-Chat & Icebreaker
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.forum_rounded, color: Colors.purple, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('🗣️ Morning Class Chit-Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navyBlue)),
                                    Text(chitChat['topic'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 18),
                          Text(
                            chitChat['chitChatUrdu'] ?? '',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 14, height: 1.8, color: Colors.black87, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              children: [
                                const Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    chitChat['icebreaker'] ?? '',
                                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Hadith of the Day
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.menu_book, color: Colors.green, size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Text('📖 Hadith of the Day / حدیثِ مبارکہ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navyBlue)),
                            ],
                          ),
                          const Divider(height: 18),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              hadith['arabic'] ?? '',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 17, height: 1.8, fontWeight: FontWeight.bold, color: AppTheme.navyBlue),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              hadith['urdu'] ?? '',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 14, height: 1.7, color: Colors.black87),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Lesson: ${hadith['lesson'] ?? ''}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Curiosity & Science Spark
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.science, color: Colors.teal, size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Text('🔬 Daily Science Spark', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navyBlue)),
                            ],
                          ),
                          const Divider(height: 18),
                          Text(science['fact'] ?? '', style: const TextStyle(fontSize: 13, height: 1.4)),
                          const SizedBox(height: 6),
                          Text(
                            science['factUrdu'] ?? '',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 13, height: 1.7, color: Colors.teal),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 4. Daily Class Challenge
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.stars_rounded, color: Colors.amber, size: 26),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              challenge,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
