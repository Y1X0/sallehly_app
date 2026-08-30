import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/success_feedback.dart';
import '../../../core/ui/directional_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/request_model.dart';
import '../../chat/screens/chat_room_screen.dart';
import '../../requests/provider/requests_provider.dart';
import '../widgets/offer_card.dart';

class OffersScreen extends StatefulWidget {
  final RequestModel request;

  const OffersScreen({
    super.key,
    required this.request,
  });

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (!mounted) return;
      context.read<RequestsProvider>().loadOffers(widget.request.id);
    });
  }

  Future<void> acceptOffer(int offerId) async {
    final t = AppLocalizations.of(context)!;
    final provider = context.read<RequestsProvider>();

    // [FIX-OFFERDECISION-01] راجع DECISIONS.md — لم يكن هناك try/catch هنا
    // إطلاقاً: عند فشل الشبكة كان الزر يتوقف عن التحميل بصمت بلا أي رسالة،
    // فلا يعرف المستخدم هل نجحت العملية أم لا.
    try {
      final request = await provider.acceptOffer(
        requestId: widget.request.id,
        offerId: offerId,
      );

      if (!mounted || request == null) return;

      showSuccessSnackBar(context, t.offersAcceptedMessage);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(request: request),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, t.offerAcceptFailedMessage);
    }
  }

  Future<void> rejectOffer(int offerId) async {
    final t = AppLocalizations.of(context)!;
    final provider = context.read<RequestsProvider>();

    try {
      await provider.rejectOffer(
        requestId: widget.request.id,
        offerId: offerId,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, t.offerRejectFailedMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final provider = context.watch<RequestsProvider>();
    final offers = provider.offers;

    return Scaffold(
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => provider.loadOffers(widget.request.id),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      _HeroCard(
                        count: offers.length,
                        service: widget.request.service,
                      ),
                      const SizedBox(height: 22),
                      SectionTitle(
                        title: t.offersSectionTitle,
                        subtitle: t.offersSectionSubtitle,
                      ),
                      const SizedBox(height: 14),
                      if (provider.loading && offers.isEmpty)
                        SizedBox(
                          height: 280,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      else if (provider.error != null && offers.isEmpty)
                        _ErrorOffers(
                          message: provider.error!,
                          onRetry: () => provider.loadOffers(widget.request.id),
                        )
                      else if (offers.isEmpty)
                        const _EmptyOffers()
                      else
                        ...offers.map((offer) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: OfferCard(
                              offer: offer,
                              loading: provider.loading,
                              onAccept: () => acceptOffer(offer.id),
                              onReject: () => rejectOffer(offer.id),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: t.backButtonTooltip,
            onPressed: onBack,
            icon: Icon(DirectionalIcons.back(context)),
          ),
          Expanded(
            child: Text(
              t.offersScreenTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final int count;
  final String service;

  const _HeroCard({
    required this.count,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      radius: 30,
      gradient: AppColors.primaryGradient,
      child: Stack(
        children: [
          Positioned(
            left: -24,
            top: -30,
            child: Icon(
              Icons.local_offer_rounded,
              size: 120,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.handshake_rounded,
                color: Colors.white,
                size: 38,
              ),
              const SizedBox(height: 18),
              Text(
                count == 0 ? t.offersWaitingTitle : t.offersReceivedCount(count),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t.offersHeroServiceLabel(service),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorOffers extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorOffers({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return GlassCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              color: AppColors.danger,
              size: 44,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            t.offersLoadFailedTitle,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
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
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(t.retryButton),
          ),
        ],
      ),
    );
  }
}

class _EmptyOffers extends StatelessWidget {
  const _EmptyOffers();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return GlassCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              Icons.local_offer_outlined,
              color: AppColors.primary,
              size: 44,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            t.offersEmptyTitle,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.offersEmptySubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}