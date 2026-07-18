import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/request_model.dart';
import '../../requests/widgets/request_status_chip.dart';

class CustomerRequestCard extends StatefulWidget {
  final RequestModel request;
  final VoidCallback onTap;

  const CustomerRequestCard({
    super.key,
    required this.request,
    required this.onTap,
  });

  @override
  State<CustomerRequestCard> createState() => _CustomerRequestCardState();
}

class _CustomerRequestCardState extends State<CustomerRequestCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
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
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(28),
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
                  RequestStatusChip(status: widget.request.status),
                  const SizedBox(height: 12),
                  Text(
                    widget.request.service,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.request.city}${widget.request.area == null || widget.request.area!.isEmpty ? '' : ' - ${widget.request.area}'}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.request.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
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
