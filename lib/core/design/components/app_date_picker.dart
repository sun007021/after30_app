import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:after30/core/design/app_platform.dart';
import 'package:after30/core/design/tokens/app_colors.dart';
import 'package:after30/core/design/tokens/app_radius.dart';

/// [showAppDatePicker]가 지원하는 모드.
enum AppDatePickerMode {
  /// 연/월/일 선택.
  date,

  /// 연/월만 선택(캘린더 월 이동 점프 등에 사용).
  monthYear,
}

/// 적응형 날짜 선택기(§4.3).
///
/// iOS: 휠 [CupertinoDatePicker](date 또는 monthYear 모드) 바텀 시트 +
/// 취소/완료. Android: 기존 [showDatePicker](Material 캘린더)를 사용한다.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initial,
  DateTime? min,
  DateTime? max,
  AppDatePickerMode mode = AppDatePickerMode.date,
}) async {
  // 시/분/초까지 포함된 min/max/initial이 섞이면(예: DateTime.now()를 각각
  // 다른 시점에 호출) 비교가 어긋날 수 있으므로 날짜 단위로 정규화한 뒤,
  // initial이 [min, max] 범위를 벗어나면 범위 안으로 당겨서 사용한다.
  // CupertinoDatePicker/showDatePicker 모두 initial이 범위를 벗어나면
  // assert 오류를 던지므로 반드시 클램프해야 한다.
  final minDate = _dateOnly(min ?? DateTime(1900));
  final maxDate = _dateOnly(max ?? DateTime(2100));
  final clampedInitial = _clampDate(_dateOnly(initial), minDate, maxDate);

  if (!isCupertino(context)) {
    if (mode == AppDatePickerMode.monthYear) {
      // Material에는 월/연 전용 피커가 없으므로 date 모드로 대체한다.
      final picked = await showDatePicker(
        context: context,
        initialDate: clampedInitial,
        firstDate: minDate,
        lastDate: maxDate,
        initialDatePickerMode: DatePickerMode.year,
      );
      return picked;
    }
    return showDatePicker(
      context: context,
      initialDate: clampedInitial,
      firstDate: minDate,
      lastDate: maxDate,
    );
  }

  var selected = clampedInitial;
  final pickerMode = mode == AppDatePickerMode.monthYear
      ? CupertinoDatePickerMode.monthYear
      : CupertinoDatePickerMode.date;

  return showModalBottomSheet<DateTime>(
    context: context,
    // W10에서 탭별 Navigator + 플로팅 탭바를 도입할 예정이므로, 피커가
    // 항상 루트 Navigator 위(탭 셸보다 위)에 표시되도록 고정한다.
    useRootNavigator: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedSuperellipseBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: SizedBox(
          height: 320,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.secondaryLabel.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('취소'),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.of(ctx).pop(selected),
                    child: const Text('완료', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: pickerMode,
                  initialDateTime: clampedInitial,
                  minimumDate: minDate,
                  maximumDate: maxDate,
                  onDateTimeChanged: (value) => selected = value,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _clampDate(DateTime value, DateTime min, DateTime max) {
  if (value.isBefore(min)) return min;
  if (value.isAfter(max)) return max;
  return value;
}
