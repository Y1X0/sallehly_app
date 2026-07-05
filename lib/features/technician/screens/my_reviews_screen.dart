import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../models/review_model.dart';
import '../../../providers/auth_provider.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  bool loading = true;
  String? error;
  List<ReviewModel> reviews = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;

    if (user == null) {
      setState(() {
        loading = false;
        error = 'تعذّر تحديد الحساب';
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await auth.getMyReviews();
      if (!mounted) return;
      setState(() {
        reviews = result;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'تعذّر تحميل التقييمات';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final ratingAvg = user?.rating ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقييماتي'),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 50),
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: load,
              child: loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        _SummaryCard(
                          ratingAvg: ratingAvg,
                          count: reviews.length,
                        ),
                        const SizedBox(height: 18),
                        if (error != null)
                          _MessageBox(
                            icon: Icons.error_outline_rounded,
                            text: error!,
                          )
                        else if (reviews.isEmpty)
                          const _MessageBox(
                            icon: Icons.star_outline_rounded,
                            text: 'لا توجد تقييمات بعد.\nستظهر هنا بعد أن يقيّمك العملاء',
                          )
                        else
                          ...reviews.map((r) => _ReviewCard(review: r)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double ratingAvg;
  final int count;

  const _SummaryCard({required this.ratingAvg, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            ratingAvg.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 46,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < ratingAvg.round();
              return Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                color: Colors.white,
                size: 26,
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            count > 0 ? 'بناءً على آخر $count تقييم' : 'لا توجد تقييمات بعد',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surface,
                child: Icon(Icons.person, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  review.customerName ?? 'عميل',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < review.stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppColors.warning,
                    size: 16,
                  );
                }),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MessageBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 64),
          const SizedBox(height: 14),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
