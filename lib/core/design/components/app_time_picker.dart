import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:after30/core/design/app_platform.dart';
import 'package:after30/core/design/tokens/app_colors.dart';

/// 적응형 시간 선택기(§4.3).
///
/// iOS: 휠 [CupertinoDatePicker](time 모드) 바텀 시트 + 취소/완료.
/// 24h/12h 표기는 기기 설정([MediaQuery.alwaysUse24HourFormatOf])을 따른다.
/// Android: 기존 [showTimePicker](Material 시계 다이얼)를 그대로 사용한다.
Future<TimeOfDay?> showAppTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) async {
  if (!isCupertino(context)) {
    return showTimePicker(context: context, initialTime: initialTime);
  }

  final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
  var selected = DateTime(2000, 1, 1, initialTime.hour, initialTime.minute);

  return showModalBottomSheet<TimeOfDay>(
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
                    onPressed: () => Navigator.of(ctx).pop(
                      TimeOfDay(hour: selected.hour, minute: selected.minute),
                    ),
                    child: const Text('완료', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: use24h,
                  initialDateTime: selected,
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
