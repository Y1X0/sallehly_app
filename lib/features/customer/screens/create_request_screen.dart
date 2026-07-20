import 'dart:io';

import 'package:flutter/material.dart';
import '../../../core/widgets/image_source_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_constants.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/success_feedback.dart';
import '../../requests/provider/requests_provider.dart';

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final formKey = GlobalKey<FormState>();

  final descriptionController = TextEditingController();
  final preferredTimeController = TextEditingController();

  String? selectedService;
  String? selectedCity;
  String? selectedArea;
  String? imagePath;

  List<String> get availableAreas {
    if (selectedCity == null) return [];
    return AppConstants.areasByCity[selectedCity] ?? [];
  }

  @override
  void initState() {
    super.initState();
    // [FIX-SERVICES-01] المهن كانت تُقرأ من قائمة ثابتة بالكود — الآن تُجلب
    // حيّة من الخادم حتى تظهر أي مهنة يضيفها الأدمن فوراً دون تحديث التطبيق.
    Future.microtask(() {
      if (!mounted) return;
      context.read<RequestsProvider>().loadMeta();
    });
  }

  @override
  void dispose() {
    descriptionController.dispose();
    preferredTimeController.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final path = await ImageSourcePicker.pick(context, maxWidth: 1400);
    if (path == null) return;

    setState(() {
      imagePath = path;
    });
  }

  Future<void> removeImage() async {
    setState(() {
      imagePath = null;
    });
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;

    final provider = context.read<RequestsProvider>();

    try {
      await provider.createRequest(
        service: selectedService!,
        city: selectedCity!,
        area: selectedArea!,
        description: descriptionController.text.trim(),
        preferredTime: preferredTimeController.text.trim(),
        imagePath: imagePath,
      );

      if (!mounted) return;

      showSuccessSnackBar(context, 'تم إنشاء الطلب بنجاح');

      Navigator.pop(context);
    } on ApiException catch (e) {
      showError(e.message);
    } catch (_) {
      showError('تعذر إنشاء الطلب');
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestsProvider>();

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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _HeroCard(),
                        const SizedBox(height: 22),

                        const SectionTitle(
                          title: 'تفاصيل الطلب',
                          subtitle: 'اختر الخدمة والمنطقة واكتب وصف واضح للمشكلة',
                        ),
                        const SizedBox(height: 14),

                        GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _dropdown(
                                label: 'الخدمة / المهنة',
                                icon: Icons.handyman_rounded,
                                value: selectedService,
                                items: (provider.meta?.services ?? [])
                                    .map((s) => s.name)
                                    .toList(),
                                onChanged: provider.loading
                                    ? null
                                    : (value) {
                                  setState(() {
                                    selectedService = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 14),
                              _dropdown(
                                label: 'المحافظة',
                                icon: Icons.location_city_rounded,
                                value: selectedCity,
                                items: AppConstants.cities,
                                onChanged: provider.loading
                                    ? null
                                    : (value) {
                                  setState(() {
                                    selectedCity = value;
                                    selectedArea = null;
                                  });
                                },
                              ),
                              const SizedBox(height: 14),
                              _dropdown(
                                label: 'المنطقة',
                                icon: Icons.place_rounded,
                                value: selectedArea,
                                items: availableAreas,
                                onChanged:
                                provider.loading || selectedCity == null
                                    ? null
                                    : (value) {
                                  setState(() {
                                    selectedArea = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: preferredTimeController,
                                decoration: const InputDecoration(
                                  labelText: 'الوقت المفضل',
                                  hintText: 'مثال: اليوم مساءً أو غداً صباحاً',
                                  prefixIcon: Icon(Icons.access_time_rounded),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: descriptionController,
                                maxLines: 5,
                                minLines: 4,
                                decoration: const InputDecoration(
                                  labelText: 'وصف المشكلة',
                                  hintText:
                                  'اكتب تفاصيل المشكلة حتى يستطيع الفني تقدير السعر والوقت بشكل أفضل',
                                  alignLabelWithHint: true,
                                  prefixIcon:
                                  Icon(Icons.description_rounded),
                                ),
                                validator: (value) {
                                  if (value == null ||
                                      value.trim().length < 10) {
                                    return 'الوصف يجب أن لا يقل عن 10 أحرف';
                                  }

                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        const SectionTitle(
                          title: 'صورة المشكلة',
                          subtitle: 'اختياري، لكنها تساعد الفنيين على فهم المشكلة',
                        ),
                        const SizedBox(height: 14),

                        _ImagePickerCard(
                          imagePath: imagePath,
                          loading: provider.loading,
                          onPick: pickImage,
                          onRemove: removeImage,
                        ),

                        const SizedBox(height: 26),

                        GradientButton(
                          label: 'نشر الطلب واستقبال العروض',
                          icon: Icons.send_rounded,
                          loading: provider.loading,
                          onPressed: provider.loading ? null : submit,
                        ),

                        const SizedBox(height: 12),

                        const _SafeNote(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required void Function(String?)? onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: AppColors.surface,
      iconEnabledColor: AppColors.textSecondary,
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'اختر $label';
        }

        return null;
      },
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
            tooltip: 'رجوع',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: Text(
              'طلب صيانة جديد',
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
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.26),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -28,
            top: -32,
            child: Icon(
              Icons.home_repair_service_rounded,
              size: 125,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.add_task_rounded,
                color: Colors.white,
                size: 38,
              ),
              SizedBox(height: 18),
              Text(
                'احكِ لنا المشكلة\nونجيبلك الفني المناسب',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'بعد نشر الطلب، سيظهر للفنيين القريبين منك وستبدأ باستقبال العروض.',
                style: TextStyle(
                  color: Colors.white70,
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

class _ImagePickerCard extends StatelessWidget {
  final String? imagePath;
  final bool loading;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _ImagePickerCard({
    required this.imagePath,
    required this.loading,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePath != null) {
      return GlassCard(
        padding: EdgeInsets.zero,
        radius: 26,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            children: [
              Image.file(
                File(imagePath!),
                width: double.infinity,
                // [RESPONSIVE-02] ارتفاع متناسب مع عرض الشاشة بدل قيمة ثابتة —
                // 210 هي القيمة الأصلية عند العرض المرجعي 390 (لا تغيير على
                // الهواتف العادية)، وتتمدد بتناسب على الأجهزة اللوحية بدل
                // صورة مضغوطة بعرض غير متناسق.
                height: MediaQuery.of(context).size.width * (210 / 390),
                fit: BoxFit.cover,
              ),
              Positioned(
                top: 12,
                left: 12,
                child: InkWell(
                  onTap: loading ? null : onRemove,
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GlassCard(
      onTap: loading ? null : onPick,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.image_rounded,
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
                  'إضافة صورة للمشكلة',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ارفع صورة واضحة إن أمكن',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.upload_rounded,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _SafeNote extends StatelessWidget {
  const _SafeNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.verified_user_rounded,
            color: AppColors.success,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'لن يتم مشاركة رقمك مع الفني داخل الدردشة. التواصل يتم بأمان داخل التطبيق.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}