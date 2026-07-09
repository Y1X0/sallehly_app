import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/widgets/image_source_picker.dart';
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

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (!mounted) return;

      context.read<SocketProvider>().joinRequest(widget.request.id);
      context.read<ChatProvider>().loadMessages(widget.request.id);
      // سجّل أنك داخل هذه المحادثة حتى لا يصلك إشعار وأنت تتابعها.
      context.read<NotificationProvider>().setActiveChat(widget.request.id);
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
      messageController.clear();

      await context.read<ChatProvider>().sendMessage(
        requestId: widget.request.id,
        body: text,
      );

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
        showError('صلاحية الموقع مرفوضة دائماً، فعّلها من إعدادات التطبيق');
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
        );

        scrollToBottom();
        return;
      }

      final hasPermission = await audioRecorder.hasPermission();

      if (!hasPermission) {
        showError('لم يتم السماح بتسجيل الصوت');
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

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().user;
    final chatProvider = context.watch<ChatProvider>();
    final messages = chatProvider.messagesFor(widget.request.id);
    final reversedMessages = messages.reversed.toList();

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
              ),
              Expanded(
                child: chatProvider.loading && messages.isEmpty
                    ? const Center(
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

                      return ChatBubble(
                        message: message,
                        isMe: isMe,
                      );
                    },
                  ),
                ),
              ),
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

class _ChatHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;

  const _ChatHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        border: const Border(
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
                  style: const TextStyle(
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
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.25),
              ),
            ),
            child: const Text(
              'آمن',
              style: TextStyle(
                color: AppColors.success,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
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
          child: const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 46,
          ),
        ),
        const SizedBox(height: 22),
        const Text(
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
          style: const TextStyle(
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
          child: const Icon(
            Icons.forum_rounded,
            color: AppColors.primary,
            size: 46,
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'لا توجد رسائل بعد',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
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