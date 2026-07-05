import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_config.dart';
import '../../../core/theme/app_colors.dart';
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

/// يجلب هيدر المصادقة (التوكن) لاستخدامه مع Image.network والصوت.
Future<Map<String, String>> _authHeaders() async {
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'sallehly_token');

  if (token != null && token.isNotEmpty) {
    return {'Authorization': 'Bearer $token'};
  }

  return {};
}

class ChatBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  final player = AudioPlayer();

  bool playing = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;

  @override
  void initState() {
    super.initState();

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
    player.dispose();
    super.dispose();
  }

  String formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> playAudio() async {
    final url = _mediaUrl(widget.message.audioUrl);

    if (playing) {
      await player.pause();
      setState(() => playing = false);
      return;
    }

    await player.play(UrlSource(url));
    setState(() => playing = true);
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
              Text(
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
    );
  }
}

class _AudioMessage extends StatelessWidget {
  final bool isMe;
  final bool playing;
  final Duration position;
  final Duration duration;
  final VoidCallback onTap;
  final String Function(Duration) formatDuration;

  const _AudioMessage({
    required this.isMe,
    required this.playing,
    required this.position,
    required this.duration,
    required this.onTap,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    final textColor = isMe ? Colors.white : AppColors.textPrimary;
    final mutedColor =
    isMe ? Colors.white.withValues(alpha: 0.75) : AppColors.textSecondary;

    return SizedBox(
      width: 215,
      child: Row(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(100),
            child: Icon(
              playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
              color: isMe ? Colors.white : AppColors.primary,
              size: 38,
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
                      playing ? 'تشغيل' : 'صوت',
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
              child: const Icon(
                Icons.location_on_rounded,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'موقع على الخريطة\nاضغط للفتح',
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

class _ImageMessage extends StatelessWidget {
  final String imageUrl;

  const _ImageMessage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // فتح الصورة بحجم كامل عند الضغط
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _FullImageView(imageUrl: imageUrl),
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
          child: FutureBuilder<Map<String, String>>(
            future: _authHeaders(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
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
              }

              return Image.network(
                imageUrl,
                headers: snapshot.data,
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
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image_outlined, color: Colors.white70),
                        SizedBox(height: 6),
                        Text(
                          'تعذّر تحميل الصورة',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
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
          future: _authHeaders(),
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
                errorBuilder: (context, error, stack) => const Text(
                  'تعذّر تحميل الصورة',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
