// [SEC-FIX-ADMINDOUBLESUBMIT-02] راجع DECISIONS.md. يخلف
// SEC-FIX-ADMINDOUBLESUBMIT-01 (كانت تحرس فقط reviewTopup/adjustUserBalance
// بحارسين مخصَّصين منفصلين، تاركة 15 دالة كتابة أخرى بلا أي حارس — نفس فئة
// "بعض الوحدات محمية، بعضها لا، بلا طريقة مرئية للتفريق" التي فُتح عليها هذا
// التعديل). كل الـ17 دالة كتابة بـAdminProvider تمرّ الآن إجبارياً عبر
// _runGuarded مشترك واحد. هذا الملف يثبت البنيتين الحرجتين اللتين طلب صاحب
// المنتج التحقق منهما صراحة:
// ١) الحارس ينجو من استثناء بالإجراء نفسه — لا يعلق true للأبد لو رمى.
// ٢) كل الـ17 دالة فعلاً تمر عبر _runGuarded، ولا دالة منها تكتب
//    actionLoading مباشرة بعد الآن — تحقُّق آلي من مصدر الملف نفسه، لا عدّ
//    يدوي عرضة للخطأ أو النسيان لاحقاً.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sallehly_app/core/api/api_client.dart';
import 'package:sallehly_app/core/api/api_exception.dart';
import 'package:sallehly_app/features/admin/data/admin_api.dart';
import 'package:sallehly_app/features/admin/provider/admin_provider.dart';
import 'package:sallehly_app/models/admin_stats_model.dart';
import 'package:sallehly_app/models/admin_user_model.dart';

class MockAdminApi extends Mock implements AdminApi {}

class MockApiClient extends Mock implements ApiClient {}

/// أسماء الـ17 دالة كتابة الحقيقية بـAdminProvider — نفس المفاتيح المُمرَّرة
/// فعلياً لـ_runGuarded('...') بالكود المصدري. أي دالة كتابة تُضاف لاحقاً
/// ولا تُضاف هنا أيضاً ستُفوِّت اختبار الاكتمال أدناه عمداً — تذكير مقصود.
const _expectedGuardedActions = [
  'toggleUser',
  'changeUserRole',
  'verifyTechnician',
  'reviewTopup',
  'updateSupportStatus',
  'toggleService',
  'updateService',
  'createService',
  'deleteService',
  'deletePackage',
  'createPackage',
  'cancelRequest',
  'changeRequestStatus',
  'updateUserProfile',
  'adjustUserBalance',
  'deleteUser',
  'updatePackage',
];

void main() {
  late MockAdminApi mockApi;
  late AdminProvider provider;

  setUp(() {
    mockApi = MockAdminApi();
    provider = AdminProvider(apiClient: MockApiClient(), apiOverride: mockApi);

    when(() => mockApi.getStats()).thenAnswer((_) async => AdminStatsModel.empty);
    when(() => mockApi.getUsers()).thenAnswer((_) async => <AdminUserModel>[]);
  });

  group('[SEC-FIX-ADMINDOUBLESUBMIT-02] الحارس ينجو من استثناء — لا يعلق true للأبد', () {
    test(
      'deleteUser الذي يرمي استثناءً: actionLoading يعود false، والمحاولة التالية لنفس الدالة تصل فعلياً للـAPI (الحارس غير عالق)',
      () async {
        var callCount = 0;
        when(() => mockApi.deleteUser(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            throw ApiException('فشل مصطنع لاختبار سلامة الحارس عند الاستثناء');
          }
          // المحاولة الثانية تنجح.
        });

        // المحاولة الأولى: يجب أن ترمي (نفس catch/rethrow الأصلي)، ثم
        // actionLoading يجب أن يعود false رغم الاستثناء — لا finally بلا
        // تنفيذ.
        await expectLater(
          () => provider.deleteUser(1),
          throwsA(isA<ApiException>()),
        );
        expect(provider.actionLoading, isFalse,
            reason: 'استثناء بالإجراء يجب أن يترك actionLoading=false عبر finally، لا عالقاً true');

        // الإثبات الحاسم: استدعاء deleteUser مرة أخرى (نفس المفتاح 'deleteUser')
        // يجب أن يصل فعلياً لـmockApi.deleteUser مرة ثانية — لو كان الحارس
        // عالقاً (لم يُزَل من _inFlightActions رغم الاستثناء)، هذا الاستدعاء
        // كان سيُرجَع فوراً بصمت بلا أي نداء API حقيقي.
        await provider.deleteUser(1);
        verify(() => mockApi.deleteUser(1)).called(2);
        expect(provider.actionLoading, isFalse);
      },
    );

    test(
      'toggleService الذي يرمي استثناءً بلا catch داخلي (يُبتلَع الخطأ صراحةً هنا فقط ليكتمل الاختبار): actionLoading يعود false أيضاً',
      () async {
        var callCount = 0;
        when(() => mockApi.toggleService(any(), any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) throw Exception('فشل مصطنع');
        });
        when(() => mockApi.getMeta()).thenAnswer((_) async => <String, dynamic>{'packages': []});
        when(() => mockApi.getAllServices()).thenAnswer((_) async => <Map<String, dynamic>>[]);

        await expectLater(
          () => provider.toggleService(1, true),
          throwsA(isA<Exception>()),
        );
        expect(provider.actionLoading, isFalse);

        await provider.toggleService(1, true);
        verify(() => mockApi.toggleService(1, true)).called(2);
      },
    );
  });

  group('[SEC-FIX-ADMINDOUBLESUBMIT-02] اكتمال التغطية — الـ17 دالة كلها فعلياً عبر _runGuarded', () {
    late String source;

    setUpAll(() {
      source = File('lib/features/admin/provider/admin_provider.dart').readAsStringSync();
    });

    test('كل دالة من الـ17 المعروفة تستدعي _runGuarded بمفتاحها الصحيح', () {
      for (final action in _expectedGuardedActions) {
        expect(
          source.contains("_runGuarded('$action'"),
          isTrue,
          reason: "الدالة '$action' لا تستدعي _runGuarded('$action', ...) — تحقّق أنها لم تُترَك بلا حارس بعد أي تعديل لاحق",
        );
      }
    });

    test('عدد نداءات _runGuarded(...) يساوي 17 بالضبط — لا دالة كتابة إضافية غير مُتوقَّعة، ولا دالة سقطت سهواً', () {
      final matches = RegExp(r"_runGuarded\('[a-zA-Z]+',").allMatches(source);
      expect(matches.length, _expectedGuardedActions.length,
          reason: 'عدد دوال _runGuarded الفعلي بالملف يجب أن يطابق القائمة المتوقَّعة تماماً — 17');
    });

    test('لا دالة كتابة تكتب actionLoading مباشرة — التعيين الوحيدان لها موجودان فقط داخل _runGuarded نفسها', () {
      // actionLoading = true تظهر مرة واحدة فقط بكل الملف (داخل _runGuarded).
      final trueAssignments = RegExp(r'actionLoading = true').allMatches(source);
      expect(trueAssignments.length, 1,
          reason: 'وُجد أكثر من موضع يكتب actionLoading = true مباشرة — دالة كتابة تتجاوز _runGuarded');

      // actionLoading = false الحرفية أُزيلت من كل دوال الكتابة — الموضع
      // الوحيد المتبقي هو تصريح الحقل نفسه (bool actionLoading = false;)،
      // لا أي تعيين داخل دالة. actionLoading يُشتَق الآن من
      // _inFlightActions.isNotEmpty داخل _runGuarded حصراً.
      final falseAssignments = RegExp(r'actionLoading = false').allMatches(source);
      expect(falseAssignments.length, 1,
          reason: 'الموضع الوحيد المتوقَّع لـ"actionLoading = false" هو تصريح الحقل — أي موضع إضافي يعني دالة كتابة تكتبه مباشرة متجاوزةً _runGuarded');
    });
  });

  group('[SEC-FIX-ADMINDOUBLESUBMIT-02] إجراءان مختلفان لا يحجب أحدهما الآخر', () {
    test('reviewTopup قيد التنفيذ لا يمنع adjustUserBalance من العمل بنفس اللحظة — actionLoading يبقى true حتى ينتهي الاثنان', () async {
      final reviewCompleter = Completer<void>();
      when(() => mockApi.reviewTopup(id: any(named: 'id'), status: any(named: 'status'), note: any(named: 'note')))
          .thenAnswer((_) => reviewCompleter.future);
      when(() => mockApi.getTopups()).thenAnswer((_) async => <Map<String, dynamic>>[]);
      when(() => mockApi.adjustUserBalance(id: any(named: 'id'), amount: any(named: 'amount'), reason: any(named: 'reason')))
          .thenAnswer((_) async => 50);

      final reviewFuture = provider.reviewTopup(id: 1, status: 'approved');
      await Future<void>.delayed(Duration.zero); // اسمح لـreviewTopup ببدء التنفيذ وتسجيل نفسها بـ_inFlightActions
      expect(provider.actionLoading, isTrue);

      // إجراء مختلف تماماً بنفس اللحظة — يجب ألا يُحجَب.
      await provider.adjustUserBalance(id: 2, amount: 10, reason: 'test');
      verify(() => mockApi.adjustUserBalance(id: 2, amount: 10, reason: 'test')).called(1);

      // reviewTopup لا يزال قيد التنفيذ فعلياً — actionLoading يجب أن يبقى
      // true (ليس false بمجرد انتهاء adjustUserBalance فقط).
      expect(provider.actionLoading, isTrue,
          reason: 'actionLoading أصبح false رغم أن reviewTopup لا يزال قيد التنفيذ فعلياً');

      reviewCompleter.complete();
      await reviewFuture;
      expect(provider.actionLoading, isFalse);
    });
  });
}
