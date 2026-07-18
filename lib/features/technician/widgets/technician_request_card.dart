import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/request_model.dart';
import '../../requests/widgets/request_status_chip.dart';

class TechnicianRequestCard extends StatefulWidget {
  final RequestModel request;
  final VoidCallback onTap;
  final bool showCustomer;

  const TechnicianRequestCard({
    super.key,
    required this.request,
    required this.onTap,
    this.showCustomer = true,
  });

  @override
  State<TechnicianRequestCard> createState() => _TechnicianRequestCardState();
}

class _TechnicianRequestCardState extends State<TechnicianRequestCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final locationText =
        '${widget.request.city}${widget.request.area == null || widget.request.area!.isEmpty ? '' : ' - ${widget.request.area}'}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(28),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onHighlightChanged: (value) => setState(() => _pressed = value),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Hero(
                        tag: 'technician-request-status-${widget.request.id}',
                        child: RequestStatusChip(status: widget.request.status),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.flash_on_rounded,
                              color: AppColors.primary,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'جديد',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Icon(
                          Icons.handyman_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.request.service,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _InfoLine(
                              icon: Icons.place_rounded,
                              text: locationText,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (widget.showCustomer && widget.request.customerName != null) ...[
                    const SizedBox(height: 12),
                    _InfoLine(
                      icon: Icons.person_rounded,
                      text: widget.request.customerName!,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    widget.request.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.6,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'عرض التفاصيل وإرسال عرض',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppColors.textPrimary,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.textSecondary,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
