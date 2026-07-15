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
import '../../../core/widgets/services_multi_select.dart';
import '../../../models/service_model.dart';
import '../../../providers/auth_provider.dart';
import '../../requests/provider/requests_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final areaController = TextEditingController();

  final formKey = GlobalKey<FormState>();

  String? selectedCity;
  // [FIX-TECH-SERVICES-01] خدمات الفني الحالية (متعددة، من 1 إلى 5) — تُهيَّأ
  // من بياناته الحالية، وتبقى محفوظة حتى لو أصبحت إحداها معطّلة لاحقاً (لا
  // تُحذف بصمت من القائمة المختارة).
  List<String> selectedServices = [];
  String? avatarPath;
  bool isTechnician = false;

  @override
  void initState() {
    super.initState();

    final user = context.read<AuthProvider>().user;
    if (user != null) {
      nameController.text = user.name;
      phoneController.text = user.phone;
      areaController.text = user.area ?? '';
      isTechnician = user.role == 'technician';
      selectedServices = List<String>.from(user.services);

      if (user.city != null && AppConstants.cities.contains(user.city)) {
        selectedCity = user.city;
      }
    }

    // [FIX-SERVICES-02] نفس مصدر البيانات المستخدم بالتسجيل وإنشاء الطلبات —
    // لا يوجد استدعاء API مكرر ولا مصدر ثانٍ للمهن.
    if (isTechnician) {
      Future.microtask(() {
        if (!mounted) return;
        context.read<RequestsProvider>().loadMeta();
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    areaController.dispose();
    super.dispose();
  }

  Future<void> pickAvatar() async {
    final path = await ImageSourcePicker.pick(
      context,
      imageQuality: 82,
      maxWidth: 800,
    );

    if (path != null) {
      setState(() {
        avatarPath = path;
      });
    }
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;

    // [FIX-TECH-SERVICES-01] نفس تحقق شاشة التسجيل (1 إلى 5 خدمات).
    if (isTechnician && selectedServices.isEmpty) {
      showError('اختر خدمة واحدة على الأقل');
      return;
    }
    if (isTechnician && selectedServices.length > 5) {
      showError('الحد الأقصى 5 خدمات');
      return;
    }

    final auth = context.read<AuthProvider>();

    try {
      await auth.updateProfile(
        name: nameController.text,
        phone: phoneController.text,
        city: selectedCity,
        area: areaController.text,
        services: isTechnician ? selectedServices : null,
        avatarPath: avatarPath,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث البيانات بنجاح')),
      );

      Navigator.pop(context);
    } on ApiException catch (e) {
      showError(e.message);
    } catch (_) {
      showError('تعذر تحديث البيانات');
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
    final loading = context.watch<AuthProvider>().loading;
    final meta = context.watch<RequestsProvider>().meta;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل الملف الشخصي'),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        padding: const EdgeInsets.fromLTRB(22, 90, 22, 22),
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (isTechnician) ...[
                GestureDetector(
                  onTap: loading ? null : pickAvatar,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                      image: avatarPath != null
                          ? DecorationImage(
                        image: FileImage(File(avatarPath!)),
                        fit: BoxFit.cover,
                      )
                          : null,
                    ),
                    child: avatarPath == null
                        ? Icon(
                      Icons.add_a_photo_rounded,
                      color: AppColors.primary,
                      size: 34,
                    )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'اضغط لتغيير الصورة الشخصية',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 18),
              ],
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'الاسم الكامل',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          final name = value?.trim() ?? '';
                          if (name.length < 2) return 'أدخل الاسم الكامل';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'رقم الهاتف',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: (value) {
                          final phone = value?.trim() ?? '';
                          if (!RegExp(r'^07\d{8}$').hasMatch(phone)) {
                            return 'رقم الهاتف يجب أن يبدأ 07 ويتكون من 10 أرقام';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCity,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'المحافظة',
                          prefixIcon: Icon(Icons.location_city_outlined),
                        ),
                        items: AppConstants.cities
                            .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c),
                        ))
                            .toList(),
                        onChanged: (value) {
                          setState(() => selectedCity = value);
                        },
                      ),
                      if (isTechnician) ...[
                        const SizedBox(height: 14),
                        Builder(builder: (context) {
                          // [FIX-TECH-SERVICES-01] نفس القائمة الحيّة المستخدمة
                          // بالتسجيل وإنشاء الطلبات — مصدر واحد فقط، بدون أي
                          // نداء API إضافي (تُحمَّل مرة عبر initState أعلاه).
                          final activeServices = meta?.services ?? [];
                          final activeNames =
                          activeServices.map((s) => s.name).toSet();

                          // أي خدمة كانت مختارة سابقاً وما عادت ضمن القائمة
                          // الفعّالة (عُطّلت من الأدمن) — نُبقيها ظاهرة كخيار
                          // قابل للإلغاء بدل حذفها بصمت من اختيار الفني.
                          final inactiveSelected = selectedServices
                              .where((s) => !activeNames.contains(s))
                              .map((s) => ServiceModel(id: 0, name: s, icon: '⚠️'))
                              .toList();

                          return ServicesMultiSelect(
                            services: [...inactiveSelected, ...activeServices],
                            selected: selectedServices,
                            onChanged: (value) {
                              setState(() => selectedServices = value);
                            },
                          );
                        }),
                      ],
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: areaController,
                        decoration: const InputDecoration(
                          labelText: 'المنطقة / الحي',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                      ),
                      const SizedBox(height: 22),
                      GradientButton(
                        label: 'حفظ التعديلات',
                        icon: Icons.save_rounded,
                        loading: loading,
                        onPressed: loading ? null : submit,
                      ),
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