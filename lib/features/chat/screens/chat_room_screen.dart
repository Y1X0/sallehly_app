import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/widgets/image_source_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../models/request_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/socket_provider.dart';
import '../provider/chat_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input.dart';

class ChatRoomScreen extends StatefulWidget {
  final RequestModel request;

  const ChatRoomScreen({
    super.key,
    required this.request,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final messageController = TextEditingController();
  final scrollController = ScrollController();
  final audioRecorder = AudioRecorder();

  bool recording = false;
  Timer? recordingTimer;
  int recordingSeconds = 0;

  // [FIX-DISCLOSURE-01] لعرض شرح سبب الصلاحية مرة واحدة فقط بكل جلسة فتح للشات
  // (وليس في كل ضغطة)، تفادياً لإزعاج المستخدم مع الحفاظ على الشفافية.
  bool _locationRationaleShown = false;
  bool _micRationaleShown = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (!mounted) return;

      context.read<SocketProvider>().joinRequest(widget.request.id);
      context.read<ChatProvider>().loadMessages(widget.request.id);
      context.read<ChatProvider>().loadBlockStatus(widget.request.id);
      // سجّل أنك داخل هذه المحادثة حتى لا يصلك إشعار وأنت تتابعها.
      final notify = context.read<NotificationProvider>();
      notify.setActiveChat(widget.request.id);
      // [FIX-NOTIF-02] صفّر فوراً أي إشعار قديم متراكم لهذه المحادثة تحديداً —
      // بقية المحادثات الأخرى غير المقروءة تبقى كما هي.
      notify.markChatNotificationsReadForRequest(widget.request.id);
    });
  }

  @override
  void dispose() {
    recordingTimer?.cancel();
    context.read<SocketProvider>().leaveRequest(widget.request.id);
    // غادرت المحادثة — اسمح بوصول إشعارات هذا الطلب مجدداً.
    context.read<NotificationProvider>().setActiveChat(null);
    messageController.dispose();
    scrollController.dispose();
    audioRecorder.dispose();
    super.dispose();
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    try {
      // [FIX-CHAT-03] كان يُمسح النص هنا قبل التأكد من نجاح الإرسال فعلياً —
      // لو فشل الإرسال (شبكة، محادثة محظورة، طلب أُغلق أثناء الكتابة)، كان
      // نص المستخدم يضيع بلا رجعة رغم ظهور رسالة خطأ فقط. الآن لا يُمسح إلا
      // بعد نجاح الإرسال الفعلي، فلا حاجة لإعادته بـcatch لأنه لم يُمسح أصلاً.
      await context.read<ChatProvider>().sendMessage(
        requestId: widget.request.id,
        body: text,
      );

      messageController.clear();

      scrollToBottom();
    } on ApiException catch (e) {
      showError(e.message);
    } catch (e) {
      showError('تعذر إرسال الرسالة: $e');
    }
  }

  Future<void> sendImage() async {
    try {
      final path = await ImageSourcePicker.pick(context, maxWidth: 1400);

      if (path == null) return;
      if (!mounted) return;

      await context.read<ChatProvider>().sendImage(
        requestId: widget.request.id,
        imagePath: path,
      );

      scrollToBottom();
    } on ApiException catch (e) {
      showError(e.message);
    } catch (e) {
      showError('تعذر إرسال الصورة: $e');
    }
  }

  Future<void> sendLocation() async {
    // [FIX-DISCLOSURE-01] اشرح سبب الحاجة للموقع قبل أي طلب صلاحية فعلي —
    // مرة واحدة فقط بهذه الجلسة. إن ألغى المستخدم، لا نطلب الصلاحية إطلاقاً.
    if (!_locationRationaleShown) {
      final proceed = await _showPermissionRationale(
        context,
        icon: Icons.location_on_rounded,
        title: 'مشاركة موقعك',
        message:
            'سنستخدم موقعك الجغرافي فقط لإرساله للطرف الآخر بهذه المحادثة '
            'ليتمكن من الوصول لمكان الخدمة. لن يُستخدم موقعك لأي غرض آخر، '
            'ولن نصل إليه إلا عند ضغطك على هذا الزر تحديداً.',
      );
      if (!mounted) return;
      _locationRationaleShown = true;
      if (!proceed) return;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        showError('فعّل خدمة الموقع GPS من إعدادات الهاتف');
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        await _showOpenSettingsDialog(
          context,
          icon: Icons.location_on_rounded,
          title: 'صلاحية الموقع مرفوضة',
          message:
              'رفضت صلاحية الموقع بشكل دائم، ولا يمكن للتطبيق طلبها مجدداً. '
              'لمشاركة موقعك، فعّل صلاحية الموقع يدوياً من إعدادات التطبيق.',
        );
        return;
      }

      if (permission == LocationPermission.denied) {
        showError('لم يتم السماح بالوصول للموقع');
        return;
      }

      Position? position;

      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        showError('تعذر تحديد الموقع، افتح GPS وجرب مرة ثانية');
        return;
      }

      if (!mounted) return;

      await context.read<ChatProvider>().sendLocation(
        requestId: widget.request.id,
        lat: position.latitude,
        lng: position.longitude,
      );

      scrollToBottom();
    } on ApiException catch (e) {
      showError(e.message);
    } catch (e) {
      showError('تعذر إرسال الموقع: $e');
    }
  }

  Future<void> toggleRecord() async {
    try {
      if (recording) {
        final path = await audioRecorder.stop();

        recordingTimer?.cancel();

        if (!mounted) return;

        final duration = recordingSeconds;

        setState(() {
          recording = false;
          recordingSeconds = 0;
        });

        if (path == null || path.isEmpty) {
          showError('لم يتم حفظ التسجيل');
          return;
        }

        if (duration < 1) {
          showError('التسجيل قصير جداً');
          return;
        }

        await context.read<ChatProvider>().sendAudio(
          requestId: widget.request.id,
          audioPath: path,
          durationSeconds: duration,
        );

        scrollToBottom();
        return;
      }

      // [FIX-DISCLOSURE-01] اشرح سبب الحاجة للميكروفون قبل أي طلب صلاحية فعلي.
      if (!_micRationaleShown) {
        final proceed = await _showPermissionRationale(
          context,
          icon: Icons.mic_rounded,
          title: 'تسجيل رسالة صوتية',
          message:
              'سنستخدم الميكروفون فقط أثناء ضغطك المستمر على زر التسجيل، '
              'لإرسال رسالة صوتية بهذه المحادثة. لا يتم أي تسجيل بالخلفية '
              'ولا بأي وقت آخر.',
        );
        if (!mounted) return;
        _micRationaleShown = true;
        if (!proceed) return;
      }

      // [FIX-PERM-02] استعلام صريح عن الحالة الفعلية (granted/denied/
      // permanentlyDenied) بدل الاكتفاء بـbool من audioRecorder.hasPermission()
      // — نفس صلاحية RECORD_AUDIO على مستوى نظام التشغيل، فطلبها هنا عبر
      // permission_handler لا يتعارض مع audioRecorder.start() لاحقاً.
      var micStatus = await Permission.microphone.status;

      if (!micStatus.isGranted) {
        micStatus = await Permission.microphone.request();
      }

      if (!micStatus.isGranted) {
        if (!mounted) return;

        if (micStatus.isPermanentlyDenied) {
          await _showOpenSettingsDialog(
            context,
            icon: Icons.mic_rounded,
            title: 'صلاحية الميكروفون مرفوضة',
            message:
                'رفضت صلاحية الميكروفون بشكل دائم، ولا يمكن للتطبيق طلبها '
                'مجدداً. لتسجيل رسالة صوتية، فعّل الصلاحية يدوياً من '
                'إعدادات التطبيق.',
          );
        } else {
          showError('لم يتم السماح بتسجيل الصوت');
        }
        return;
      }

      final dir = Directory.systemTemp;
      final path =
          '${dir.path}/sallehly_audio_${DateTime.now().millisecondsSinceEpoch}.wav';

      await audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          bitRate: 64000,
          sampleRate: 44100,
        ),
        path: path,
      );

      if (!mounted) return;

      setState(() {
        recording = true;
        recordingSeconds = 0;
      });

      recordingTimer?.cancel();
      recordingTimer = Timer.periodic(
        const Duration(seconds: 1),
            (_) {
          if (!mounted) return;

          setState(() {
            recordingSeconds++;
          });

          if (recordingSeconds >= 30) {
            toggleRecord();
          }
        },
      );
    } on ApiException catch (e) {
      recordingTimer?.cancel();

      if (mounted) {
        setState(() {
          recording = false;
          recordingSeconds = 0;
        });
      }

      showError(e.message);
    } catch (e) {
      recordingTimer?.cancel();

      if (mounted) {
        setState(() {
          recording = false;
          recordingSeconds = 0;
        });
      }

      showError('تعذر تسجيل الصوت: $e');
    }
  }

  void scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;

      if (scrollController.hasClients) {
        scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(message),
      ),
    );
  }

  void showInfo(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.success,
        content: Text(message),
      ),
    );
  }

  // [FIX-UGC-01] حظر/إلغاء حظر الطرف الآخر بهذه المحادثة (سياسة UGC).
  Future<void> blockUserFlow() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('حظر هذا المستخدم'),
        content: const Text(
          'لن يتمكن أي منكما من إرسال رسائل للآخر بهذا الطلب بعد الحظر. '
          'يمكنك إلغاء الحظر لاحقاً في أي وقت.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('حظر'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    try {
      await context.read<ChatProvider>().blockUser(widget.request.id);
      if (!mounted) return;
      showInfo('تم حظر هذا المستخدم');
    } on ApiException catch (e) {
      showError(e.message);
    } catch (_) {
      showError('تعذر تنفيذ الحظر، حاول مرة أخرى');
    }
  }

  Future<void> unblockUserFlow() async {
    try {
      await context.read<ChatProvider>().unblockUser(widget.request.id);
      if (!mounted) return;
      showInfo('تم إلغاء الحظر');
    } on ApiException catch (e) {
      showError(e.message);
    } catch (_) {
      showError('تعذر إلغاء الحظر، حاول مرة أخرى');
    }
  }

  // [FIX-UGC-01] الإبلاغ عن آخر رسالة/المحادثة عموماً — راجع chat_bubble.dart
  // للإبلاغ عن رسالة محددة بالضغط المطوّل عليها مباشرة.
  Future<void> reportConversationFlow() async {
    final reason = await _pickReportReason(context);
    if (reason == null) return;
    if (!mounted) return;

    try {
      final message = await context.read<ChatProvider>().reportMessage(
        requestId: widget.request.id,
        reason: reason,
      );
      if (!mounted) return;
      showInfo(message);
    } on ApiException catch (e) {
      showError(e.message);
    } catch (_) {
      showError('تعذر إرسال البلاغ، حاول مرة أخرى');
    }
  }

  /// إبلاغ عن رسالة محددة (يُستدعى من الضغط المطوّل على فقاعة الرسالة).
  Future<void> reportMessageFlow(int messageId) async {
    final reason = await _pickReportReason(context);
    if (reason == null) return;
    if (!mounted) return;

    try {
      final message = await context.read<ChatProvider>().reportMessage(
        requestId: widget.request.id,
        messageId: messageId,
        reason: reason,
      );
      if (!mounted) return;
      showInfo(message);
    } on ApiException catch (e) {
      showError(e.message);
    } catch (_) {
      showError('تعذر إرسال البلاغ، حاول مرة أخرى');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().user;
    final chatProvider = context.watch<ChatProvider>();
    final messages = chatProvider.messagesFor(widget.request.id);
    final reversedMessages = messages.reversed.toList();
    final blockStatus = chatProvider.blockStatusFor(widget.request.id);
    final isChatBlocked = blockStatus?.isChatBlocked ?? false;

    final location =
        '${widget.request.city}${widget.request.area == null || widget.request.area!.isEmpty ? '' : ' - ${widget.request.area}'}';

    return Scaffold(
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
          child: Column(
            children: [
              _ChatHeader(
                title: widget.request.service,
                subtitle: location,
                onBack: () => Navigator.pop(context),
                isBlockedByMe: blockStatus?.blockedByMe ?? false,
                onToggleBlock: (blockStatus?.blockedByMe ?? false)
                    ? unblockUserFlow
                    : blockUserFlow,
                onReport: reportConversationFlow,
              ),
              if (isChatBlocked)
                Container(
                  width: double.infinity,
                  color: AppColors.danger.withValues(alpha: 0.12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    (blockStatus?.blockedByMe ?? false)
                        ? '🚫 لقد حظرت هذا المستخدم — لا يمكن تبادل الرسائل بينكما'
                        : '🚫 لا يمكنك إرسال رسائل لهذا المستخدم حالياً',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              Expanded(
                child: chatProvider.loading && messages.isEmpty
                    ? Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                )
                    : chatProvider.error != null && messages.isEmpty
                    ? _ChatErrorState(
                  message: chatProvider.error!,
                  onRetry: () =>
                      context.read<ChatProvider>().loadMessages(widget.request.id),
                )
                    : messages.isEmpty
                    ? const _EmptyChat()
                    : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () {
                    return context
                        .read<ChatProvider>()
                        .loadMessages(widget.request.id);
                  },
                  child: ListView.separated(
                    controller: scrollController,
                    reverse: true,
                    padding:
                    const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    itemCount: reversedMessages.length,
                    separatorBuilder: (context, index) {
                      return const SizedBox(height: 10);
                    },
                    itemBuilder: (context, index) {
                      final message = reversedMessages[index];
                      final isMe = currentUser != null &&
                          message.senderId == currentUser.id;

                      // [FIX-CHATBUBBLE-01] بدون key، تُطابق Flutter عناصر
                      // القائمة حسب الموقع (index) لا حسب هوية الرسالة —
                      // بقائمة reverse:true تُدرَج فيها رسائل جديدة أعلى
                      // القائمة باستمرار، هذا كان يُعيد استخدام نفس
                      // _ChatBubbleState (ومعه AudioPlayer/duration/position)
                      // لرسالة مختلفة كلياً بدل إنشاء حالة جديدة، فـinitState
                      // (حيث تُقرأ مدة الصوت المخزَّنة) لا يُعاد تنفيذه أبداً
                      // لرسائل الصوت الجديدة — وهذا بالضبط سبب عدم ظهور مدة
                      // الرسالة الصوتية فوراً إلا بعد الضغط على تشغيل (اللحظة
                      // الوحيدة المتبقية التي تُحدِّث duration فعلياً).
                      return ChatBubble(
                        key: ValueKey(message.id),
                        message: message,
                        isMe: isMe,
                        onReport: isMe
                            ? null
                            : () => reportMessageFlow(message.id),
                      );
                    },
                  ),
                ),
              ),
              if (isChatBlocked)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: AppColors.surface,
                  child: Text(
                    'التواصل معطّل حالياً بسبب الحظر',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                ChatInput(
                  controller: messageController,
                  sending: chatProvider.sending,
                  recording: recording,
                  recordingSeconds: recordingSeconds,
                  onSend: sendMessage,
                  onLocation: sendLocation,
                  onRecord: toggleRecord,
                  onImage: sendImage,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [FIX-UGC-01] ورقة سفلية موحّدة لاختيار سبب البلاغ — تُستخدم للإبلاغ عن
/// رسالة محددة أو عن المحادثة عموماً.
/// [FIX-DISCLOSURE-01] حوار توضيحي (Prominent Disclosure) يُعرض قبل أي طلب
/// صلاحية حساسة فعلي (موقع/ميكروفون)، يشرح بوضوح: لماذا، ومتى تُستخدم،
/// وأنها اختيارية بالكامل. يعيد true فقط لو ضغط المستخدم "متابعة".
Future<bool> _showPermissionRationale(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      icon: Icon(icon, color: AppColors.primary, size: 32),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(
        '$message\n\nهذه الميزة اختيارية بالكامل — يمكنك دائماً إلغاء الأمر.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary, height: 1.6),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('متابعة'),
        ),
      ],
    ),
  );

  return result == true;
}

/// [FIX-PERM-01] يُعرض عند رفض صلاحية (موقع/ميكروفون) بشكل دائم — بعكس
/// _showPermissionRationale الذي يُعرض قبل الطلب، هذا الحوار يُعرض بعد رفض
/// فعلي نهائي، ويقدّم خياراً وحيداً مفيداً: الانتقال لإعدادات التطبيق لتفعيل
/// الصلاحية يدوياً من هناك.
Future<void> _showOpenSettingsDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      icon: Icon(icon, color: AppColors.danger, size: 32),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary, height: 1.6),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await openAppSettings();
          },
          child: const Text('فتح إعدادات التطبيق'),
        ),
      ],
    ),
  );
}

Future<String?> _pickReportReason(BuildContext context) {
  const reasons = [
    'محتوى مسيء أو غير لائق',
    'مضايقة أو تهديد',
    'محاولة احتيال أو نصب',
    'محتوى غير مناسب (صورة/تسجيل صوتي)',
    'سبب آخر',
  ];

  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سبب الإبلاغ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              ...reasons.map(
                (r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(r),
                  onTap: () => Navigator.pop(ctx, r),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ChatHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final bool isBlockedByMe;
  final VoidCallback onToggleBlock;
  final VoidCallback onReport;

  const _ChatHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.isBlockedByMe,
    required this.onToggleBlock,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.handyman_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // [FIX-UGC-01] قائمة الإبلاغ/الحظر — Google Play UGC policy
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded,
                color: AppColors.textSecondary),
            onSelected: (value) {
              if (value == 'report') onReport();
              if (value == 'block') onToggleBlock();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, color: AppColors.danger),
                    SizedBox(width: 10),
                    Text('إبلاغ عن المحادثة'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(
                      isBlockedByMe
                          ? Icons.lock_open_rounded
                          : Icons.block_rounded,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 10),
                    Text(isBlockedByMe ? 'إلغاء حظر المستخدم' : 'حظر المستخدم'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ChatErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 130),
        Container(
          width: 92,
          height: 92,
          margin: const EdgeInsets.symmetric(horizontal: 100),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 46,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'تعذّر تحميل الرسائل',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 130),
        Container(
          width: 92,
          height: 92,
          margin: const EdgeInsets.symmetric(horizontal: 100),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(
            Icons.forum_rounded,
            color: AppColors.primary,
            size: 46,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'لا توجد رسائل بعد',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'ابدأ المحادثة الآن بخصوص الطلب. يمكنك إرسال رسالة، موقع، صورة، أو تسجيل صوتي.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}