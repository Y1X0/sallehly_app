import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../provider/wallet_provider.dart';
import '../widgets/package_card.dart';
import 'topup_request_screen.dart';

class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key});

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (!mounted) return;
      context.read<WalletProvider>().loadPackages();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'باقات الشحن',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: wallet.loadPackages,
        child: wallet.loading && wallet.packages.isEmpty
            ? Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        )
            : wallet.error != null && wallet.packages.isEmpty
            ? ListView(
          padding: const EdgeInsets.all(28),
          children: [
            const SizedBox(height: 160),
            Icon(
              Icons.error_outline_rounded,
              color: AppColors.danger,
              size: 76,
            ),
            const SizedBox(height: 16),
            Text(
              'تعذّر تحميل الباقات',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              wallet.error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: TextButton.icon(
                onPressed: wallet.loadPackages,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
              ),
            ),
          ],
        )
            : wallet.packages.isEmpty
            ? ListView(
          padding: const EdgeInsets.all(28),
          children: [
            SizedBox(height: 180),
            Icon(
              Icons.inventory_2_outlined,
              color: AppColors.primary,
              size: 76,
            ),
            SizedBox(height: 16),
            Text(
              'لا توجد باقات حالياً',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        )
            : ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: wallet.packages.length,
          separatorBuilder: (context, index) {
            return const SizedBox(height: 16);
          },
          itemBuilder: (context, index) {
            final pkg = wallet.packages[index];

            return PackageCard(
              package: pkg,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TopupRequestScreen(package: pkg),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}