import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/widgets/app_background.dart';
import '../../../l10n/app_localizations.dart';
import '../provider/admin_provider.dart';

/// [FEAT-ADMINREQUESTDETAIL-01] راجع DECISIONS.md — أول شاشة تجمع صورة كاملة
/// لطلب واحد (الطلب + كل العروض + المحادثة الكاملة) لغرض الحكم بنزاع، بدل
/// تجميعها يدوياً من ثلاث شاشات منفصلة كما كان الوضع سابقاً. عرض للقراءة
/// فقط — لا أي زر إجراء هنا (الإلغاء/تغيير الحالة يبقيان بشاشة القائمة
/// admin_requests_screen.dart، هذه الشاشة تُفتَح منها بالضغط على بطاقة طلب).
class AdminRequestDetailScreen extends StatefulWidget {
  final int requestId;

  const AdminRequestDetailScreen({super.key, required this.requestId});

  @override
  State<AdminRequestDetailScreen> createState() => _AdminRequestDetailScreenState();
}

class _AdminRequestDetailScreenState extends State<AdminRequestDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<AdminProvider>().loadRequestDetail(widget.requestId);
    });
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} - ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final admin = context.watch<AdminProvider>();
    final detail = admin.requestDetail;
    final request = detail?['request'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          t.requestNumberLabel(widget.requestId),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
          child: admin.requestDetailLoading && detail == null
              ? const Center(child: CircularProgressIndicator())
              : admin.requestDetailError != null && detail == null
                  ? _ErrorState(
                      message: admin.requestDetailError!,
                      onRetry: () => context.read<AdminProvider>().loadRequestDetail(widget.requestId),
                    )
                  : detail == null || request == null
                      ? const SizedBox.shrink()
                      : RefreshIndicator(
                          onRefresh: () => context.read<AdminProvider>().loadRequestDetail(widget.requestId),
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 66, 20, 20),
                            children: [
                              _RequestSummaryCard(request: request, formatDate: _formatDate),
                              const SizedBox(height: 20),
                              _SectionTitle(t.adminRequestOffersSectionTitle((detail['offers'] as List).length)),
                              ..._offerTiles(context, detail['offers'] as List),
                              const SizedBox(height: 20),
                              _SectionTitle(t.adminRequestChatSectionTitle),
                              _ChatTranscript(messages: detail['messages'] as List, formatDate: _formatDate),
                            ],
                          ),
                        ),
        ),
      ),
    );
  }

  List<Widget> _offerTiles(BuildContext context, List offers) {
    final t = AppLocalizations.of(context)!;
    if (offers.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(t.noneLabel, style: TextStyle(color: AppColors.textMuted)),
        ),
      ];
    }
    return offers
        .map((o) => _SimpleTile(
              title: '${o['technician_name'] ?? ''} • ${formatJod(context, double.tryParse('${o['price']}') ?? 0)}',
              subtitle: '${o['duration'] ?? ''} • ${o['status']}',
              trailing: _formatDate(o['created_at']?.toString()),
            ))
        .toList();
  }
}

class _RequestSummaryCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final String Function(String?) formatDate;

  const _RequestSummaryCard({required this.request, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final status = '${request['status'] ?? ''}';
    final isCancelled = status == 'ملغي';
    final commission = request['commission_charged'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${request['service'] ?? ''}',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(status, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow(context, Icons.person_rounded, t.customerLabel,
              '${request['customer_name'] ?? '-'} • ${request['customer_phone'] ?? ''}'),
          if (request['technician_name'] != null)
            _infoRow(context, Icons.engineering_rounded, t.technicianLabel,
                '${request['technician_name']} • ${request['technician_phone'] ?? ''}'),
          _infoRow(context, Icons.location_on_rounded, t.cityLabel,
              '${request['city'] ?? '-'}${request['area'] != null ? ' - ${request['area']}' : ''}'),
          if (commission != null)
            _infoRow(context, Icons.payments_rounded, t.commissionChargedLabel, formatJod(context, double.tryParse('$commission') ?? 0)),
          if (isCancelled) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (request['cancel_reason'] != null && '${request['cancel_reason']}'.isNotEmpty)
                    Text(
                      '${t.cancellationReasonLabel}: ${request['cancel_reason']}',
                      style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700),
                    ),
                  if (request['cancelled_by_name'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${t.cancelledByLabel}: ${request['cancelled_by_name']} • ${formatDate(request['cancelled_at']?.toString())}',
                        style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 13)),
          Expanded(child: Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _ChatTranscript extends StatelessWidget {
  final List messages;
  final String Function(String?) formatDate;

  const _ChatTranscript({required this.messages, required this.formatDate});

  /// [FEAT-ADMINREQUESTDETAIL-01] عرض للقراءة فقط لغرض مراجعة نزاع — يعرض
  /// معاينة نصية قصيرة لمرفقات الصورة/الصوت/الموقع (نفس منطق المعاينة
  /// المستخدَم أصلاً بقائمة المحادثات chats_screen.dart) بدل تشغيلها أو
  /// عرضها فعلياً، ونفس نصوص t.chatPreviewImage/Audio/Location الموجودة —
  /// لا حاجة لمشغّل وسائط كامل لمجرد قراءة سياق نزاع.
  String _previewBody(BuildContext context, String body) {
    final t = AppLocalizations.of(context)!;
    if (body.startsWith('[image]')) return t.chatPreviewImage;
    if (body.startsWith('[audio]')) return t.chatPreviewAudio;
    if (body.startsWith('[location]')) return t.chatPreviewLocation;
    return body;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    if (messages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(t.noMessagesYetTitle, style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: messages.map((m) {
          final map = Map<String, dynamic>.from(m as Map);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${map['sender_name'] ?? ''}',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatDate(map['created_at']?.toString()),
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _previewBody(context, '${map['body'] ?? ''}'),
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 15)),
    );
  }
}

class _SimpleTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String trailing;

  const _SimpleTile({required this.title, this.subtitle, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(subtitle!, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(trailing, style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 40),
            ),
            const SizedBox(height: 18),
            Text(
              t.requestLoadFailedTitle,
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(t.retryButton),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
