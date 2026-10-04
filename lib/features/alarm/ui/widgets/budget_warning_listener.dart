import 'dart:async';

import 'package:flutter/material.dart';
import 'package:after30/core/design/design.dart';
import 'package:after30/features/alarm/data/alarm_service.dart';

/// [AlarmService.budgetWarnings](iOS 알림 64개 예산 초과 안내)를 구독해
/// [AppToast]로 보여주는 래퍼.
///
/// 알람 목록과 약 등록 화면이 각각 이 위젯을 두는데, 두 화면은 겹쳐 있을 수
/// 있다(등록 화면이 목록 위에 push됨). 그래서 이벤트가 올 때 이 위젯의
/// 화면이 실제로 보이는 상태([TickerMode] 활성)일 때만 토스트를 띄워, 보이지
/// 않는 탭이나 가려진 화면에서 토스트가 중복/엉뚱하게 뜨지 않게 한다.
class BudgetWarningListener extends StatefulWidget {
  const BudgetWarningListener({super.key, this.warnings, required this.child});

  /// 테스트 주입용. 지정하지 않으면 실제 [AlarmService.budgetWarnings].
  final Stream<String>? warnings;
  final Widget child;

  @override
  State<BudgetWarningListener> createState() => _BudgetWarningListenerState();
}

class _BudgetWarningListenerState extends State<BudgetWarningListener> {
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant BudgetWarningListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.warnings != widget.warnings) {
      _subscription?.cancel();
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription = (widget.warnings ?? AlarmService.budgetWarnings).listen((message) {
      if (!mounted || !TickerMode.of(context)) return;
      AppToast.show(context, message);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
