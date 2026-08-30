import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/authenticated_media.dart';
import '../../../core/widgets/bidi_text.dart';
import '../../../core/widgets/success_feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/message_model.dart';

/// يبني الرابط الكامل للوسائط (صورة/صوت).
/// إذا كان المسار القادم من السيرفر رابطاً كاملاً (يبدأ بـ http)
/// نستخدمه كما هو، وإلا نضيف عليه الـ baseUrl.
String _mediaUrl(String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }
  return '${AppConfig.baseUrl}$path';
}

class ChatBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  // [FIX-UGC-01] استدعاء اختياري للإبلاغ عن هذه الرسالة (ضغط مطوّل).
  // null لرسائلي أنا (لا معنى للإبلاغ عن رسالة أرسلتها بنفسك).
  final VoidCallback? onReport;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onReport,
  });

  // [SEC-FIX-AUDIOAUTH-01] يسمح للاختبارات فقط باستبدال عميل Dio المستخدَم
  // لجلب بايتات الرسالة الصوتية المصادَق عليها، بدل الاتصال بشبكة حقيقية
  // (بما فيها baseUrl الفعلي لإنتاج sallehly.com). null دائماً بالتطبيق
  // الفعلي — لا يغيّر أي سلوك إنتاجي.
  @visibleForTesting
  static Dio? debugAudioDio;

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  // [FIX-CRASH-01] كان يُنشأ AudioPlayer() بدون شرط لكل فقاعة رسالة — حتى
  // الرسائل النصية العادية — رغم أنه غير مستخدم إلا لرسائل الصوت. على بعض
  // البيئات (بدون جهاز صوت فعّال) هذا يرمي استثناء أصلي غير معالَج يُسقط
  // التطبيق بالكامل. الآن يُنشأ فقط عند الحاجة الفعلية لرسالة صوتية.
  AudioPlayer? _player;

  bool playing = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;

  // [SEC-FIX-AUDIOAUTH-01] راجع DECISIONS.md (كلا المستودعين) —
  // audioplayers's UrlSource لا يدعم هيدرز إطلاقاً (تحقَّق مباشرة من
  // توثيق الحزمة، كل الإصدارات لحد الأحدث)، فكانت رسائل الشات الصوتية
  // تُشغَّل من express.static العام بلا أي مصادقة — نفس الفجوة التي أُغلقت
  // لصور الشات بـSEC-FIX-UPLOADS-01. البديل: تحميل البايتات كاملة عبر طلب
  // مصادَق صريح (نفس هيدرز authHeadersForMediaUrl المستخدَمة أصلاً للصور)،
  // ثم تشغيلها من الذاكرة مباشرة (BytesSource) بلا أي ملف مؤقت. البايتات
  // تُخزَّن هنا بعد أول تحميل ناجح — ضغطات تشغيل/إيقاف لاحقة لا تُعيد التحميل.
  Uint8List? _audioBytes;
  bool _loadingAudio = false;

  @override
  void initState() {
    super.initState();

    if (!widget.message.isAudio) return;

    // [FIX-AUDIODUR-01] اعرض المدة المخزَّنة فوراً بدل "00:00" لحين بدء
    // التشغيل — قبل هذا التغيير لم تكن المدة تظهر أبداً إلا بعد ضغط تشغيل
    // فعلي (لحظة تحميل AudioPlayer لبيانات الملف).
    final storedSeconds = widget.message.audioDurationSeconds;
    if (storedSeconds != null && storedSeconds > 0) {
      duration = Duration(seconds: storedSeconds);
    }

    final player = _player = AudioPlayer();

    player.onDurationChanged.listen((value) {
      if (mounted) setState(() => duration = value);
    });

    player.onPositionChanged.listen((value) {
      if (mounted) setState(() => position = value);
    });

    player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        playing = false;
        position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  String formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> playAudio() async {
    final player = _player;
    if (player == null || _loadingAudio) return;

    if (playing) {
      await player.pause();
      setState(() => playing = false);
      return;
    }

    try {
      var bytes = _audioBytes;
      if (bytes == null) {
        setState(() => _loadingAudio = true);
        final url = _mediaUrl(widget.message.audioUrl);
        final headers = await authHeadersForMediaUrl(url);
        final dio = ChatBubble.debugAudioDio ?? Dio();
        final response = await dio.get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            headers: headers,
          ),
        );
        bytes = Uint8List.fromList(response.data ?? const []);
        _audioBytes = bytes;
      }

      if (!mounted) return;
      await player.play(BytesSource(bytes));
      setState(() {
        playing = true;
        _loadingAudio = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingAudio = false);
        final t = AppLocalizations.of(context)!;
        showErrorSnackBar(context, t.playAudioFailedMessage);
      }
    }
  }

  Future<void> openLocation() async {
    final parts = widget.message.locationPayload.split(',');
    if (parts.length != 2) return;

    final lat = parts[0];
    final lng = parts[1];

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.isMe;
    final message = widget.message;

    final time = message.createdAt == null
        ? ''
        : '${message.createdAt!.hour.toString().padLeft(2, '0')}:${message.createdAt!.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
      child: GestureDetector(
        onLongPress: widget.onReport,
        child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          gradient: isMe ? AppColors.primaryGradient : null,
          color: isMe ? null : AppColors.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(isMe ? 6 : 22),
            bottomRight: Radius.circular(isMe ? 22 : 6),
          ),
          border: isMe ? null : Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
          isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            if (message.isAudio)
              _AudioMessage(
                isMe: isMe,
                playing: playing,
                loading: _loadingAudio,
                position: position,
                duration: duration,
                onTap: playAudio,
                formatDuration: formatDuration,
              )
            else if (message.isLocation)
              _LocationMessage(
                isMe: isMe,
                onTap: openLocation,
              )
            else if (message.isImage)
              _ImageMessage(
                imageUrl: _mediaUrl(message.imageUrl),
              )
            else
              BidiText(
                message.body,
                style: TextStyle(
                  color: isMe ? Colors.white : AppColors.textPrimary,
                  height: 1.55,
                  fontSize: 15,
                ),
              ),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.72)
                          : AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  // علامة "تمت المشاهدة" تظهر فقط لرسائلي أنا
                  if (isMe) ...[
                    const SizedBox(width: 5),
                    Icon(
                      message.seen ? Icons.done_all_rounded : Icons.done_rounded,
                      size: 15,
                      color: message.seen
                          ? const Color(0xFF7DE2FF)
                          : Colors.white.withValues(alpha: 0.6),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}

class _AudioMessage extends StatelessWidget {
  final bool isMe;
  final bool playing;
  final bool loading;
  final Duration position;
  final Duration duration;
  final VoidCallback onTap;
  final String Function(Duration) formatDuration;

  const _AudioMessage({
    required this.isMe,
    required this.playing,
    required this.loading,
    required this.position,
    required this.duration,
    required this.onTap,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    final textColor = isMe ? Colors.white : AppColors.textPrimary;
    final mutedColor =
    isMe ? Colors.white.withValues(alpha: 0.75) : AppColors.textSecondary;
    final iconColor = isMe ? Colors.white : AppColors.primary;

    return SizedBox(
      width: 215,
      child: Row(
        children: [
          InkWell(
            onTap: loading ? null : onTap,
            borderRadius: BorderRadius.circular(100),
            child: SizedBox(
              width: 38,
              height: 38,
              child: loading
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                      ),
                    )
                  : Icon(
                      playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                      color: iconColor,
                      size: 38,
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: isMe
                      ? Colors.white.withValues(alpha: 0.22)
                      : AppColors.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isMe ? Colors.white : AppColors.secondary,
                  ),
                  borderRadius: BorderRadius.circular(50),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Icon(
                      Icons.mic_rounded,
                      size: 14,
                      color: mutedColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      duration.inSeconds == 0
                          ? '00:00'
                          : formatDuration(duration),
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      playing ? t.audioMessagePlaying : t.audioMessageLabel,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationMessage extends StatelessWidget {
  final bool isMe;
  final VoidCallback onTap;

  const _LocationMessage({
    required this.isMe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.14)
              : AppColors.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isMe
                ? Colors.white.withValues(alpha: 0.20)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                Icons.location_on_rounded,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t.locationMessageLabel,
                style: TextStyle(
                  color: isMe ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageMessage extends StatefulWidget {
  final String imageUrl;

  const _ImageMessage({required this.imageUrl});

  @override
  State<_ImageMessage> createState() => _ImageMessageState();
}

class _ImageMessageState extends State<_ImageMessage> {
  // [SEC-FIX-UPLOADS-01] راجع DECISIONS.md (backend) — صور الشات أصبحت وراء
  // مصادقة حقيقية، فهذه الصورة تحتاج هيدر Authorization الآن (بعكس وقت
  // [FIX-CHATIMG-03] أدناه، يوم كان التوكن غير مستخدَم أصلاً من الخادم).
  // الحل هون يحترم درس [FIX-CHATIMG-03] بالضبط: الهيدرز تُجلَب مرة واحدة فقط
  // بـinitState وتُخزَّن بالـstate — لا FutureBuilder جديد بكل build() (نفس
  // العلّة اللي كانت تُلغي ImageCache وتُعيد التحميل من الصفر مع كل حدث
  // Socket.IO يمسّ شاشة الشات).
  Map<String, String>? _headers;

  @override
  void initState() {
    super.initState();
    authHeadersForMediaUrl(widget.imageUrl).then((headers) {
      if (mounted) setState(() => _headers = headers);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_headers == null) {
      return const SizedBox(
        width: 200,
        height: 200,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        // فتح الصورة بحجم كامل عند الضغط
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _FullImageView(imageUrl: widget.imageUrl),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 220,
            maxHeight: 260,
          ),
          child: Image.network(
            widget.imageUrl,
            headers: _headers,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 200,
                height: 200,
                color: Colors.black.withValues(alpha: 0.2),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stack) {
              return Container(
                width: 200,
                height: 120,
                color: Colors.black.withValues(alpha: 0.25),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.broken_image_outlined, color: Colors.white70),
                    const SizedBox(height: 6),
                    Text(
                      AppLocalizations.of(context)!.imageLoadFailedMessage,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FullImageView extends StatelessWidget {
  final String imageUrl;

  const _FullImageView({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: FutureBuilder<Map<String, String>>(
          future: authHeadersForMediaUrl(imageUrl),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const CircularProgressIndicator(color: Colors.white);
            }

            return InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Image.network(
                imageUrl,
                headers: snapshot.data,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => Text(
                  AppLocalizations.of(context)!.imageLoadFailedMessage,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
