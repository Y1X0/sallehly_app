import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../../models/service_model.dart';

/// [FIX-TECH-SERVICES-01] اختيار خدمات الفني كـ "شرائح" متعددة (Multi-select)
/// بدل Dropdown لخدمة واحدة فقط. يفرض حداً أدنى وأقصى (افتراضياً 1-5).
///
/// [FIX-TECH-SERVICES-02] بصندوق واحد مطوي بنفس شكل باقي حقول الفورم
/// (حدود، تعبئة، زوايا مدوّرة) — يظهر بس ملخص "اسم الحقل + العدّاد + سهم"،
/// وبالضغط على السهم تنفتح/تنطوي شبكة الخدمات تحته بدل ما تظهر مفتوحة دائماً
/// وتاخذ مساحة كبيرة من الشاشة من أول وهلة.
class ServicesMultiSelect extends StatefulWidget {
  final List<ServiceModel> services;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final int min;
  final int max;
  final bool enabled;
  final bool initiallyExpanded;

  const ServicesMultiSelect({
    super.key,
    required this.services,
    required this.selected,
    required this.onChanged,
    this.min = 1,
    this.max = 5,
    this.enabled = true,
    this.initiallyExpanded = false,
  });

  @override
  State<ServicesMultiSelect> createState() => _ServicesMultiSelectState();
}

class _ServicesMultiSelectState extends State<ServicesMultiSelect> {
  late bool _expanded = widget.initiallyExpanded;

  void _toggle(String name) {
    if (!widget.enabled) return;

    final next = List<String>.from(widget.selected);
    if (next.contains(name)) {
      next.remove(name);
    } else {
      if (next.length >= widget.max) return; // وصلنا للحد الأقصى
      next.add(name);
    }
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final belowMin = selected.length < widget.min;
    final atMax = selected.length >= widget.max;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── رأس الصندوق: نفس مظهر باقي حقول الفورم (حدود + تعبئة + زوايا) ──
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: widget.enabled
              ? () => setState(() => _expanded = !_expanded)
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: belowMin ? AppColors.danger : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.handyman_outlined,
                    color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selected.isEmpty
                        ? 'الخدمات / المهن'
                        : selected.join('، '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected.isEmpty
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${selected.length}/${widget.max}',
                  style: TextStyle(
                    color: atMax ? AppColors.warning : AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (belowMin) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              widget.min == 1
                  ? 'يجب اختيار خدمة واحدة على الأقل'
                  : 'يجب اختيار ${widget.min} خدمات على الأقل',
              style: TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
        ],

        // ── المحتوى القابل للطي: شبكة الخدمات ──
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState:
          _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.services.map((service) {
                final isSelected = selected.contains(service.name);
                final disabled = !widget.enabled || (!isSelected && atMax);

                return GestureDetector(
                  onTap: disabled ? null : () => _toggle(service.name),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.28)
                          : AppColors.card
                          .withValues(alpha: disabled ? 0.4 : 0.8),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color:
                        isSelected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(service.icon ?? '🔧',
                            style: const TextStyle(fontSize: 15)),
                        const SizedBox(width: 6),
                        Text(
                          service.name,
                          style: TextStyle(
                            color: disabled
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          secondChild: const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }
}