import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:after30/core/design/app_platform.dart';
import 'package:after30/core/design/tokens/app_colors.dart';

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
  final minDate = min ?? DateTime(1900);
  final maxDate = max ?? DateTime(2100);

  if (!isCupertino(context)) {
    if (mode == AppDatePickerMode.monthYear) {
      // Material에는 월/연 전용 피커가 없으므로 date 모드로 대체한다.
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: minDate,
        lastDate: maxDate,
        initialDatePickerMode: DatePickerMode.year,
      );
      return picked;
    }
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: minDate,
      lastDate: maxDate,
    );
  }

  var selected = initial;
  final pickerMode = mode == AppDatePickerMode.monthYear
      ? CupertinoDatePickerMode.monthYear
      : CupertinoDatePickerMode.date;

  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: SizedBox(
          height: 320,
          child: Column(
            children: [
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
                  initialDateTime: initial,
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
