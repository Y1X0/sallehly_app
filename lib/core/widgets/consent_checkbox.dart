import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../features/settings/screens/privacy_policy_screen.dart';
import '../theme/app_colors.dart';

/// خانة موافقة إلزامية على سياسة الخصوصية قبل التسجيل (متطلّب Google Play
/// لموافقة صريحة قبل جمع بيانات المستخدم، بما فيها الرقم الوطني للفنيين).
/// تُستخدم بشاشتَي تسجيل العميل والفني معاً بدل تكرار نفس المنطق.
class ConsentCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const ConsentCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.6,
                  ),
                  children: [
                    const TextSpan(text: 'أوافق على '),
                    TextSpan(
                      text: 'سياسة الخصوصية وشروط الاستخدام',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyScreen(),
                            ),
                          );
                        },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
