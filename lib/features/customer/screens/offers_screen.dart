import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/section_title.dart';
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
    final provider = context.read<RequestsProvider>();

    final request = await provider.acceptOffer(
      requestId: widget.request.id,
      offerId: offerId,
    );

    if (!mounted || request == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم قبول العرض وفتح المحادثة'),
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(request: request),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      const SectionTitle(
                        title: 'عروض الفنيين',
                        subtitle: 'اختر العرض الأنسب لك لفتح المحادثة',
                      ),
                      const SizedBox(height: 14),
                      if (provider.loading && offers.isEmpty)
                        const SizedBox(
                          height: 280,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
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
                              onReject: () async {
                                await provider.rejectOffer(
                                  requestId: widget.request.id,
                                  offerId: offer.id,
                                );
                              },
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const Expanded(
            child: Text(
              'العروض',
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
                count == 0 ? 'بانتظار العروض' : 'وصلتك $count عروض',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'الخدمة: $service',
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

class _EmptyOffers extends StatelessWidget {
  const _EmptyOffers();

  @override
  Widget build(BuildContext context) {
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
            child: const Icon(
              Icons.local_offer_outlined,
              color: AppColors.primary,
              size: 44,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'لا يوجد عروض بعد',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'عند وصول عروض من الفنيين ستظهر هنا، ويمكنك قبول العرض المناسب.',
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