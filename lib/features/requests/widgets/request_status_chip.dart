import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/request_status.dart';

class RequestStatusChip extends StatelessWidget {
  final String status;

  const RequestStatusChip({
    super.key,
    required this.status,
  });

  Color _colorFor(RequestStatus requestStatus) {
    return switch (requestStatus) {
      RequestStatus.completed => AppColors.success,
      RequestStatus.cancelled => AppColors.danger,
      RequestStatus.offersReceived => AppColors.warning,
      RequestStatus.inProgress => AppColors.secondary,
      // waitingForOffers/offerSelected/awaitingPaymentConfirmation/unknown —
      // no distinct color before this enum existed either; preserved as-is.
      _ => AppColors.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final requestStatus = RequestStatus.fromWire(status);
    final color = _colorFor(requestStatus);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        requestStatus.label(t, rawWire: status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12.5,
        ),
      ),
    );
  }
}