# [SEC-FIX-CTXAWAIT-01] استخدام BuildContext بعد await بلا حراسة — 15 موقعاً

## الاكتشاف
تدقيق شامل (طُلب صراحة) لكل `State` تحوي `async`/`await` (53 ملفاً فُحصت
بالكامل، لا عيّنة) كشف 15 موقعاً يستخدم `context` (غالباً عبر
`AppLocalizations.of(context)`، وموقع واحد عبر `ScaffoldMessenger.of(context)`
خام) **بعد** `await` بلا أي فحص `mounted`/`context.mounted` يحمي ذلك الاستخدام
تحديداً — رغم أن نفس هذه الملفات تستخدم النمط الصحيح بمواضع أخرى (مثال:
`chat_room_screen.dart`'s `blockUserFlow()`/`unblockUserFlow()`، اللتان
تلتقطان `t` قبل أي `await`).

**الأثر الحقيقي:** لو أُلغي تثبيت الودجت (المستخدم رجع للخلف، أغلق bottom
sheet، إلخ) أثناء انتظار طلب شبكة، ثم فشل ذلك الطلب، محاولة قراءة
`AppLocalizations.of(context)` أو `ScaffoldMessenger.of(context)` على
context غير مثبَّت تعطي استثناءً ("Looking up a deactivated widget's
ancestor is unsafe"). أخطر موقعين فعلياً: `support_screen.dart` (فتح
تذكرة دعم، bottom sheet يُغلَق بسهولة أثناء الإرسال) و`chat_room_screen.dart`
(6 مواضع — إرسال رسالة/صورة/موقع/تسجيل صوتي/بلاغ، أكثر شاشة استخداماً
بالتطبيق، على شبكات جوال متذبذبة).

## نقطة دقيقة — `showErrorSnackBar`/`showSuccessSnackBar` تبدو آمنة وليست كذلك دائماً
`lib/core/widgets/success_feedback.dart`'s `showErrorSnackBar(context, message)`
يفحص `context.mounted` **داخلها** فعلاً. لكن Dart يُقيِّم كل معاملات الدالة
**قبل** استدعائها — فلو كان `message` نفسه تعبيراً يستخدم `context` (مثل
`AppLocalizations.of(context)!.xxx`)، هذا التعبير يُنفَّذ وقد ينهار **قبل**
أن تصل السيطرة أصلاً لفحص `context.mounted` داخل `showErrorSnackBar`. الدالة
لا تحمي معامِلاتها، فقط جسمها هي. **لا تفترض أن تمرير أي شيء عبر
`showErrorSnackBar`/`showSuccessSnackBar` يجعله آمناً تلقائياً — المعامل
نفسه يجب أن يكون بالفعل قيمة مُلتقَطة مسبقاً (متغيّر عادي)، لا تعبيراً حياً
يقرأ `context`.**

## الإصلاح
كل الـ15 موقعاً: نمط واحد ثابت — التقاط `final t = AppLocalizations.of(context)!;`
(أو `final messenger = ScaffoldMessenger.of(context);` بموقع `support_screen.dart`
اليتيم الذي يستخدم `ScaffoldMessenger` خاماً) **مرة واحدة بأول الدالة، قبل
أي `await`**، ثم استخدام هذا المتغيّر المُلتقَط بكل مكان لاحقاً — بما فيه
داخل `catch`. لماذا هذا يكفي رغم تعدّد الـ`await` أحياناً بنفس الدالة (مثال:
`sendLocation()`، `toggleRecord()`): `t`/`messenger` بعد الالتقاط مجرّد
مرجع Dart عادي، لا يلمس `context`/شجرة الودجت مرة أخرى إطلاقاً — قراءته لاحقاً
آمنة دائماً بغضّ النظر عن حالة تثبيت الودجت وقتها، فلا حاجة لالتقاط جديد بعد
كل `await`.

## تحقّق — مسح شامل لنفس الفئة من الأخطاء
بعد الإصلاح، بحث كامل بالمشروع عن أي استدعاء آخر لدالة "آمنة" (`showErrorSnackBar`،
`showSuccessSnackBar`، أو أي `showInfo` محلي بنفس النمط) يستقبل معاملاً يستخدم
`context` مباشرة (`AppLocalizations.of(context)` أو ما شابه) — لم يُعثر على أي
حالة إضافية. كل استخدامات `AppLocalizations.of(context)` المتبقية إما (أ) داخل
`build()` (متزامن، لا خطر إطلاقاً)، أو (ب) بعد فحص `mounted`/`context.mounted`
مباشر يحمي ذلك الاستخدام بالذات بلا أي `await` بينهما.

## نطاق متروك عمداً
هذا المسح مقصور على `AppLocalizations.of(context)`/`ScaffoldMessenger.of(context)`
كوسيطين لدوال "آمنة" — لم يُدقَّق كل استخدام `Theme.of(context)`/`MediaQuery.of(context)`
بنفس الأسلوب الدقيق (رغم أن التدقيق الأوسع لكل استخدام `context` بعد `await`
غطّى 53 ملفاً بالكامل ولم يجد أي حالة من هذه الأنواع). أي اكتشاف مستقبلي من
هذه الفئة يستحق نفس المعالجة الفورية، لا افتراض أن هذا الإصلاح غطّى كل شيء
للأبد.
