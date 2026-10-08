import 'models.dart';

/// Adhkar and duas bundled with the app: short, fixed, and available offline.
class LocalContent {
  static const morning = <Dhikr>[
    Dhikr(id: 'm1', count: 1, source: 'رواه مسلم', text: '«أصبحنا وأصبح الملك لله، والحمد لله، لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير»'),
    Dhikr(id: 'm2', count: 1, source: 'رواه الترمذي', text: '«اللهم بك أصبحنا، وبك أمسينا، وبك نحيا، وبك نموت، وإليك النشور»'),
    Dhikr(id: 'm3', count: 3, source: 'رواه أبو داود والترمذي', text: '«بسم الله الذي لا يضر مع اسمه شيء في الأرض ولا في السماء وهو السميع العليم»'),
    Dhikr(id: 'm4', count: 3, source: 'رواه أبو داود', text: '«رضيت بالله ربًا، وبالإسلام دينًا، وبمحمد ﷺ نبيًا»'),
    Dhikr(id: 'm5', count: 100, source: 'رواه مسلم', text: '«سبحان الله وبحمده»'),
  ];

  static const evening = <Dhikr>[
    Dhikr(id: 'e1', count: 1, source: 'رواه مسلم', text: '«أمسينا وأمسى الملك لله، والحمد لله، لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير»'),
    Dhikr(id: 'e2', count: 1, source: 'رواه الترمذي', text: '«اللهم بك أمسينا، وبك أصبحنا، وبك نحيا، وبك نموت، وإليك المصير»'),
    Dhikr(id: 'e3', count: 3, source: 'رواه أبو داود والترمذي', text: '«بسم الله الذي لا يضر مع اسمه شيء في الأرض ولا في السماء وهو السميع العليم»'),
    Dhikr(id: 'e4', count: 3, source: 'رواه مسلم', text: '«أعوذ بكلمات الله التامات من شر ما خلق»'),
    Dhikr(id: 'e5', count: 100, source: 'رواه مسلم', text: '«سبحان الله وبحمده»'),
  ];

  static const general = <Dhikr>[
    Dhikr(id: 'g1', count: 10, source: 'متفق عليه', text: '«لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير»'),
    Dhikr(id: 'g2', count: 1, source: 'رواه مسلم', text: '«سبحان الله، والحمد لله، ولا إله إلا الله، والله أكبر»'),
    Dhikr(id: 'g3', count: 1, source: 'متفق عليه', text: '«لا حول ولا قوة إلا بالله»'),
    Dhikr(id: 'g4', count: 100, source: 'رواه مسلم', text: '«أستغفر الله وأتوب إليه»'),
  ];

  static const duas = <Dua>[
    Dua(id: 'd1', source: 'رواه ابن ماجه', text: '«اللهم إني أسألك علمًا نافعًا، ورزقًا طيبًا، وعملًا متقبلًا»'),
    Dua(id: 'd2', source: 'متفق عليه', text: '«ربنا آتنا في الدنيا حسنة، وفي الآخرة حسنة، وقنا عذاب النار»'),
    Dua(id: 'd3', source: 'رواه مسلم', text: '«اللهم إني أسألك الهدى والتقى والعفاف والغنى»'),
    Dua(id: 'd4', source: 'رواه الترمذي', text: '«يا مقلب القلوب ثبت قلبي على دينك»'),
    Dua(id: 'd5', source: 'رواه أبو داود والنسائي', text: '«اللهم أعني على ذكرك وشكرك وحسن عبادتك»'),
    Dua(id: 'd6', source: 'رواه مسلم', text: '«اللهم أصلح لي ديني الذي هو عصمة أمري، وأصلح لي دنياي التي فيها معاشي، وأصلح لي آخرتي التي فيها معادي، واجعل الحياة زيادة لي في كل خير، واجعل الموت راحة لي من كل شر»'),
    Dua(id: 'd7', source: 'رواه البخاري', text: '«اللهم إني أعوذ بك من الهم والحزن، والعجز والكسل، والجبن والبخل، وضلع الدين وغلبة الرجال»'),
  ];

  /// Same dua for everyone on the same day.
  static Dua duaFor(DateTime day) => duas[_dayIndex(day) % duas.length];

  static int _dayIndex(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;
}
