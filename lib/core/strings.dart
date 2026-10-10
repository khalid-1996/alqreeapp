/// App UI strings. Arabic is primary, English secondary.
/// Religious content (Quran, hadith, adhkar) always stays Arabic.
class S {
  final bool en;
  const S(this.en);

  String _t(String ar, String english) => en ? english : ar;

  String get appName => _t('القارئ', 'Al-Qari');
  String get greeting => _t('السلام عليكم', 'Assalamu alaikum');

  // Tabs
  String get home => _t('الرئيسية', 'Home');
  String get reciters => _t('القراء', 'Reciters');
  String get radios => _t('الإذاعات', 'Radios');
  String get adhkar => _t('الأذكار', 'Adhkar');
  String get more => _t('المزيد', 'More');

  // Welcome
  String get welcomeLine => _t('القرآن رفيق يومك\nاستمع بخشوع وهدوء', 'The Quran, your daily companion');
  String get featureReciters => _t('تلاوات كبار القرّاء بمختلف الروايات', 'Recitations by renowned reciters');
  String get featureRadios => _t('إذاعات القرآن على مدار الساعة', 'Quran radio, around the clock');
  String get featureDaily => _t('حديث ودعاء اليوم، والأذكار مع العداد', 'Daily hadith, dua and adhkar counter');
  String get start => _t('ابدأ', 'Start');
  String get noAccount => _t('بدون تسجيل دخول · لا نجمع أي بيانات', 'No sign-in · No data collected');

  // Home
  String get hadithOfDay => _t('حديث اليوم', 'Hadith of the day');
  String get duaOfDay => _t('دعاء اليوم', 'Dua of the day');
  String get wamdat => _t('ومضات اليوم', 'Today\'s reflection');
  String get typeHadith => _t('حديث', 'Hadith');
  String get typeDua => _t('دعاء', 'Dua');
  String get typeAyah => _t('آية', 'Ayah');
  String get readExplanation => _t('الرواية كاملة والشرح', 'Full narration & explanation');
  String stoppedAt(String pos) => _t('وقفت عند $pos', 'Stopped at $pos');
  String get moreLink => _t('المزيد ←', 'More →');
  String get savedToFav => _t('حُفظ في المفضلة', 'Saved');
  String get continueListening => _t('أكمل الاستماع', 'Continue listening');
  String get favorites => _t('المفضلة', 'Favorites');
  String get favoritesSub => _t('السور والقراء والأحاديث المحفوظة', 'Saved surahs, reciters and hadiths');
  String get morningAdhkar => _t('أذكار الصباح', 'Morning adhkar');
  String get eveningAdhkar => _t('أذكار المساء', 'Evening adhkar');
  String get adhkarTileSub => _t('تتبدل تلقائيًا حسب الوقت', 'Switches with the time of day');
  String get seeAll => _t('عرض الكل', 'See all');
  String get live => _t('مباشر', 'Live');

  // Lists
  String get searchReciter => _t('ابحث عن قارئ...', 'Search reciters...');
  String get searchRadio => _t('ابحث عن إذاعة...', 'Search radios...');
  String get all => _t('الكل', 'All');
  String get nowPlaying => _t('يُشغَّل الآن', 'Now playing');
  String get liveStream => _t('بث مباشر', 'Live stream');
  String get liveAllDay => _t('بث مباشر على مدار الساعة', 'Live, 24/7');
  String get surahs => _t('السور', 'Surahs');
  String surahCount(int n) => _t('$n سورة', '$n surahs');

  // Player
  String get recitation => _t('تلاوة سورة', 'Recitation');
  String get modeNext => _t('التالي', 'Next');
  String get modeRepeat => _t('تكرار', 'Repeat');
  String get modeShuffle => _t('عشوائي', 'Shuffle');
  String get nothingPlaying => _t('لا يوجد شيء قيد التشغيل', 'Nothing is playing');

  // Hadith / share
  String get copy => _t('نسخ النص', 'Copy');
  String get copied => _t('تم نسخ النص', 'Copied');
  String get shareText => _t('مشاركة كنص', 'Share text');
  String get shareImage => _t('مشاركة كصورة', 'Share image');
  String get fontUp => _t('تكبير الخط', 'Larger');
  String get fontDown => _t('تصغير الخط', 'Smaller');
  String get story => _t('ستوري 9:16', 'Story 9:16');
  String get post => _t('بوست 4:5', 'Post 4:5');
  String get wide => _t('أفقي 16:9', 'Wide 16:9');
  String get share => _t('مشاركة', 'Share');
  String get shareFailed => _t('تعذّر إنشاء الصورة، حاول مرة أخرى', 'Could not create the image');

  // Adhkar
  String get morning => _t('الصباح', 'Morning');
  String get evening => _t('المساء', 'Evening');
  String get general => _t('عامة', 'General');
  String get tapToCount => _t('اضغط على الذكر للعد', 'Tap a dhikr to count');
  String progress(int done, int total) => _t('أتممت $done من $total', '$done of $total done');
  String get resetCounters => _t('إعادة العداد', 'Reset');
  String get fromHisn => _t('من حصن المسلم', 'From Hisn al-Muslim');

  // More / settings
  String get settings => _t('الإعدادات', 'Settings');
  String get language => _t('اللغة', 'Language');
  String get languageValue => _t('العربية', 'English');
  String get fontSize => _t('حجم الخط', 'Text size');
  String get fontSmall => _t('صغير', 'Small');
  String get fontMedium => _t('متوسط', 'Medium');
  String get fontLarge => _t('كبير', 'Large');
  String get about => _t('عن التطبيق', 'About');
  String get sources => _t('المصادر والحقوق', 'Sources & credits');
  String get privacy => _t('سياسة الخصوصية', 'Privacy policy');
  String get hadiths => _t('الأحاديث', 'Hadiths');
  String get noFavorites => _t('لم تحفظ شيئًا بعد', 'Nothing saved yet');

  // Notifications
  String get notifications => _t('الإشعارات', 'Notifications');
  String get notifOn => _t('مفعّلة', 'On');
  String get notifOff => _t('متوقفة', 'Off');
  String get inviteTitle => _t('ومضة كل يوم، وتذكير الجمعة', 'A daily reflection, and a Friday reminder');
  String get inviteBody => _t('إشعار واحد هادئ في اليوم. تقدر تغيّر وقته أو تقلّله متى ما تبي.',
      'One calm notification a day. Change the time or send fewer whenever you like.');
  String get enable => _t('فعّل', 'Turn on');
  String get notNow => _t('ليس الآن', 'Not now');
  String get permissionOff => _t('الإشعارات غير مسموحة لتطبيق القارئ', 'Notifications are not allowed for Al-Qari');
  String get permissionHelp => _t('اسمح بها من إعدادات الجهاز ← التطبيقات ← القارئ ← الإشعارات',
      'Allow them in device Settings → Apps → Al-Qari → Notifications');
  String get allow => _t('السماح', 'Allow');
  String get wamdaNotif => _t('ومضات اليوم', 'Daily reflection');
  String get wamdaNotifSub => _t('حديث أو دعاء أو آية', 'A hadith, dua or ayah');
  String get time => _t('الوقت', 'Time');
  String get howOften => _t('كم مرة', 'How often');
  String get daily => _t('يوميًا', 'Daily');
  String get threeWeekly => _t('٣ مرات بالأسبوع', '3× a week');
  String get weekly => _t('أسبوعيًا', 'Weekly');
  String get threeWeeklyHint => _t('السبت والاثنين والأربعاء', 'Saturday, Monday and Wednesday');
  String get weeklyHint => _t('كل اثنين', 'Every Monday');
  String get fridayNotif => _t('تذكير الجمعة', 'Friday reminder');
  String get fridayNotifSub => _t('سورة الكهف والصلاة على النبي ﷺ. يوم الجمعة يغني عن الومضة.',
      'Surah Al-Kahf and salawat. On Fridays it replaces the reflection.');
  String get adhkarNotif => _t('تذكير الأذكار', 'Adhkar reminders');
  String get adhkarNotifSub => _t('لا نذكّرك إذا أتممتها', 'Skipped once you have finished them');
  String get quiet => _t('بدون إزعاج', 'Keep it quiet');
  String get silent => _t('إشعارات صامتة', 'Silent notifications');
  String get silentSub => _t('تظهر بدون صوت ولا اهتزاز', 'No sound, no vibration');
  String get pause => _t('إيقاف مؤقت', 'Pause');
  String get pauseNone => _t('لا', 'No');
  String get pauseDay => _t('يوم', 'A day');
  String get pauseWeek => _t('أسبوع', 'A week');
  String pausedUntil(String d) => _t('متوقفة حتى $d', 'Paused until $d');
  String perWeek(int n) => n == 0
      ? _t('لن تصلك إشعارات', 'You will get no notifications')
      : _t('تقريبًا $n ${n == 1 ? 'إشعار' : 'إشعارات'} في الأسبوع', 'About $n a week');
  String get tryIt => _t('جرّب إشعارًا الآن', 'Send a sample now');
  String get sampleSent => _t('أرسلنا لك إشعارًا تجريبيًا', 'Sample sent');
  String get notifPrivacy => _t('الإشعارات تُجدول على جهازك فقط، ولا نرسل أي بيانات.',
      'Notifications are scheduled on your device. Nothing is sent anywhere.');
  String get chooseReciterForKahf => _t('اختر قارئًا لتستمع لسورة الكهف', 'Pick a reciter to listen to Al-Kahf');

  // Errors
  String get offline => _t('تحتاج اتصال بالإنترنت للاستماع', 'An internet connection is needed to listen');
  String get loadFailed => _t('تعذّر التحميل، تأكد من الاتصال', 'Could not load. Check your connection');
  String get retry => _t('إعادة المحاولة', 'Retry');
  String get playFailed => _t('تعذّر تشغيل البث، حاول لاحقًا', 'Could not play this stream');
}
