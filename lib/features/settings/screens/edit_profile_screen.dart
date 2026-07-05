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
import '../../../providers/auth_provider.dart';

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

      if (user.city != null && AppConstants.cities.contains(user.city)) {
        selectedCity = user.city;
      }
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

    final auth = context.read<AuthProvider>();

    try {
      await auth.updateProfile(
        name: nameController.text,
        phone: phoneController.text,
        city: selectedCity,
        area: areaController.text,
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
                        ? const Icon(
                            Icons.add_a_photo_rounded,
                            color: AppColors.primary,
                            size: 34,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
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
