import 'dart:io';

import 'package:flutter/material.dart';
import '../../../core/widgets/image_source_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_constants.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/services_multi_select.dart';
import '../../../providers/auth_provider.dart';
import '../../requests/provider/requests_provider.dart';
import 'verify_otp_screen.dart';

class TechnicianRegisterScreen extends StatefulWidget {
  const TechnicianRegisterScreen({super.key});

  @override
  State<TechnicianRegisterScreen> createState() =>
      _TechnicianRegisterScreenState();
}

class _TechnicianRegisterScreenState extends State<TechnicianRegisterScreen> {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final nationalController = TextEditingController();


  bool hidePassword = true;
  String? avatarPath;
  List<String> selectedServices = [];
  String? selectedCity;
  String? selectedArea;

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
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    nationalController.dispose();
    super.dispose();
  }

  Future<void> pickAvatar() async {
    final path = await ImageSourcePicker.pick(
      context,
      imageQuality: 75,
      maxWidth: 1200,
    );

    if (path == null) return;

    setState(() {
      avatarPath = path;
    });
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;

    if (avatarPath == null || avatarPath!.isEmpty) {
      showError('مطلوب صورة شخصية للفني');
      return;
    }

    // [FIX-TECH-SERVICES-01] تحقق صريح من عدد الخدمات المختارة (1 إلى 5) قبل
    // الإرسال — نفس الحد المفروض بصريًا بودجت ServicesMultiSelect نفسها.
    if (selectedServices.isEmpty) {
      showError('اختر خدمة واحدة على الأقل');
      return;
    }
    if (selectedServices.length > 5) {
      showError('الحد الأقصى 5 خدمات');
      return;
    }

    final auth = context.read<AuthProvider>();

    try {
      final result = await auth.register(
        role: 'technician',
        name: nameController.text,
        email: emailController.text,
        phone: phoneController.text,
        password: passwordController.text,
        city: selectedCity,
        nationalNumber: nationalController.text,
        services: selectedServices,
        areas: [selectedArea!],
        avatarPath: avatarPath,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyOtpScreen(
            email: result.email,
          ),
        ),
      );
    } on ApiException catch (e) {
      showError(e.message);
    } catch (_) {
      showError('حدث خطأ أثناء إنشاء الحساب');
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
        backgroundColor: Colors.transparent,
        title: const Text('حساب فني جديد'),
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        safeArea: false,
        child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 66, 22, 22),
          child: Form(
            key: formKey,
            child: Column(
              children: [
                _AvatarPicker(
                  avatarPath: avatarPath,
                  onTap: loading ? null : pickAvatar,
                ),
                const SizedBox(height: 14),
                Text(
                  'إنشاء حساب فني',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'أضف بياناتك حتى يتمكن العملاء من اختيارك بثقة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                _field(
                  controller: nameController,
                  label: 'الاسم الكامل',
                  icon: Icons.person_outline,
                  validator: (value) {
                    if (value == null || value.trim().length < 2) {
                      return 'الرجاء إدخال الاسم الكامل';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _field(
                  controller: emailController,
                  label: 'البريد الإلكتروني',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (!email.contains('@')) {
                      return 'البريد الإلكتروني غير صحيح';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _field(
                  controller: phoneController,
                  label: 'رقم الهاتف',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  validator: (value) {
                    final phone = value?.trim() ?? '';
                    if (!RegExp(r'^07\d{8}$').hasMatch(phone)) {
                      return 'رقم الهاتف يجب أن يبدأ 07 ويتكون من 10 أرقام';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _field(
                  controller: nationalController,
                  label: 'الرقم الوطني',
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  validator: (value) {
                    final national = value?.trim() ?? '';
                    if (!RegExp(r'^\d{10}$').hasMatch(national)) {
                      return 'الرقم الوطني يجب أن يكون 10 أرقام';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                ServicesMultiSelect(
                  services: meta?.services ?? [],
                  selected: selectedServices,
                  enabled: !loading,
                  onChanged: (value) {
                    setState(() {
                      selectedServices = value;
                    });
                  },
                ),
                const SizedBox(height: 14),
                _dropdown(
                  label: 'المحافظة',
                  icon: Icons.location_city_outlined,
                  value: selectedCity,
                  items: AppConstants.cities,
                  onChanged: loading
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
                  label: 'منطقة العمل',
                  icon: Icons.place_outlined,
                  value: selectedArea,
                  items: availableAreas,
                  onChanged: loading || selectedCity == null
                      ? null
                      : (value) {
                    setState(() {
                      selectedArea = value;
                    });
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: passwordController,
                  obscureText: hidePassword,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: loading
                          ? null
                          : () {
                        setState(() {
                          hidePassword = !hidePassword;
                        });
                      },
                      icon: Icon(
                        hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 8) {
                      return 'كلمة السر يجب أن تكون 8 أحرف على الأقل';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: loading ? null : submit,
                  child: loading
                      ? const CircularProgressIndicator(
                    color: Colors.black,
                  )
                      : const Text(
                    'إنشاء حساب فني',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextDirection? textDirection,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textDirection: textDirection,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: validator,
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
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
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

class _AvatarPicker extends StatelessWidget {
  final String? avatarPath;
  final VoidCallback? onTap;

  const _AvatarPicker({
    required this.avatarPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = avatarPath != null && avatarPath!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: hasImage ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.surface,
              backgroundImage: hasImage ? FileImage(File(avatarPath!)) : null,
              child: hasImage
                  ? null
                  : Icon(
                Icons.add_a_photo_rounded,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              hasImage ? 'تم اختيار الصورة الشخصية' : 'اختر صورة شخصية',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'الصورة مطلوبة لإنشاء حساب فني',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}