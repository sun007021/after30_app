import 'package:flutter/material.dart';
import 'package:after30/core/design/design.dart';

/// 디자인 시스템 컴포넌트를 한 화면에서 확인하는 디버그 전용 갤러리.
///
/// `kDebugMode`에서만 `/dev/design-gallery` 라우트로 노출된다(main.dart).
class DesignGalleryPage extends StatefulWidget {
  const DesignGalleryPage({super.key});

  @override
  State<DesignGalleryPage> createState() => _DesignGalleryPageState();
}

class _DesignGalleryPageState extends State<DesignGalleryPage> {
  final _textController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _switchValue = true;
  bool _checked = true;
  String _segment = 'male';
  String _log = '(결과가 여기에 표시됩니다)';

  @override
  void dispose() {
    _textController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _setLog(String message) => setState(() => _log = message);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.groupedBackground,
      appBar: AppBar(title: const Text('디자인 갤러리')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('현재 플랫폼', Text(isCupertino(context) ? 'iOS/Cupertino 분기' : 'Android/Material 분기')),
          _section('결과 로그', Text(_log)),
          _section('AppButton', _buttonDemo()),
          _section('AppTextField', _textFieldDemo()),
          _section('다이얼로그', _dialogDemo()),
          _section('시트 / 피커', _sheetPickerDemo()),
          _section('AppSwitch / AppCheckmark', _switchDemo()),
          _section('AppSegmentedControl', _segmentedDemo()),
          _section('AppActivityIndicator', const AppActivityIndicator()),
          _section('AppToast', _toastDemo()),
          _section('GlassSurface', _glassDemo()),
          _section('AppNavBar', _navBarDemo()),
          _section('AppGroupedSection / AppListTile', _groupedSectionDemo()),
          _section('AppSwipeActions', _swipeActionsDemo()),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.footnote),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buttonDemo() {
    return Column(
      children: [
        AppButton(label: 'Filled', variant: AppButtonVariant.filled, onPressed: () => _setLog('Filled 버튼 탭')),
        const SizedBox(height: 8),
        AppButton(label: 'Tinted', variant: AppButtonVariant.tinted, onPressed: () => _setLog('Tinted 버튼 탭')),
        const SizedBox(height: 8),
        AppButton(label: 'Outline', variant: AppButtonVariant.outline, onPressed: () => _setLog('Outline 버튼 탭')),
        const SizedBox(height: 8),
        AppButton(label: 'Text', variant: AppButtonVariant.text, onPressed: () => _setLog('Text 버튼 탭')),
        const SizedBox(height: 8),
        AppButton(label: 'Loading', variant: AppButtonVariant.filled, loading: true, onPressed: () {}),
        const SizedBox(height: 8),
        AppButton(label: 'Disabled', variant: AppButtonVariant.filled, onPressed: null),
        const SizedBox(height: 8),
        AppButton(
          label: 'Medium',
          size: AppButtonSize.medium,
          expand: false,
          onPressed: () => _setLog('Medium 버튼 탭'),
        ),
      ],
    );
  }

  Widget _textFieldDemo() {
    return Column(
      children: [
        AppTextField(
          controller: _textController,
          label: '이름',
          placeholder: '홍길동',
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _phoneController,
          label: '전화번호',
          placeholder: '010-0000-0000',
          keyboardType: TextInputType.phone,
          showKeyboardDoneBar: true,
          inputFormatters: [PhoneNumberFormatter()],
          autofillHints: const [AutofillHints.telephoneNumber],
        ),
        const SizedBox(height: 12),
        const AppTextField(label: '오류 예시', placeholder: '비밀번호', errorText: '8자 이상 입력해 주세요', obscureText: true, showObscureToggle: true),
      ],
    );
  }

  Widget _dialogDemo() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        AppButton(
          label: '알럿',
          expand: false,
          onPressed: () => showAppAlert(context: context, title: '안내', message: '알럿 예시입니다.'),
        ),
        AppButton(
          label: '확인/취소',
          expand: false,
          onPressed: () async {
            final ok = await showAppConfirm(context: context, title: '확인', message: '진행하시겠습니까?');
            _setLog('확인 결과: $ok');
          },
        ),
        AppButton(
          label: '파괴적 확인',
          expand: false,
          variant: AppButtonVariant.outline,
          onPressed: () async {
            final ok = await showAppConfirm(
              context: context,
              title: '삭제',
              message: '정말 삭제하시겠습니까?',
              confirmLabel: '삭제',
              destructive: true,
            );
            _setLog('삭제 확인 결과: $ok');
          },
        ),
        AppButton(
          label: '액션 시트',
          expand: false,
          onPressed: () async {
            final value = await showAppActionSheet<String>(
              context: context,
              title: '옵션 선택',
              actions: const [
                AppActionSheetAction(label: '옵션 1', value: 'opt1'),
                AppActionSheetAction(label: '삭제', value: 'delete', destructive: true),
              ],
            );
            _setLog('액션 시트 결과: $value');
          },
        ),
        AppButton(
          label: '텍스트 입력 알럿',
          expand: false,
          onPressed: () async {
            final value = await showAppTextInputAlert(
              context: context,
              title: '그룹 이름 변경',
              initialValue: '우리 가족',
            );
            _setLog('입력값: $value');
          },
        ),
      ],
    );
  }

  Widget _sheetPickerDemo() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        AppButton(
          label: '시트 열기',
          expand: false,
          onPressed: () => showAppSheet<void>(
            context: context,
            builder: (ctx) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('시트 내용', style: AppTypography.body),
            ),
          ),
        ),
        AppButton(
          label: '시간 선택',
          expand: false,
          onPressed: () async {
            final time = await showAppTimePicker(context: context, initialTime: TimeOfDay.now());
            if (!mounted) return;
            _setLog('선택한 시간: ${time?.format(context)}');
          },
        ),
        AppButton(
          label: '날짜 선택',
          expand: false,
          onPressed: () async {
            final date = await showAppDatePicker(context: context, initial: DateTime.now());
            _setLog('선택한 날짜: $date');
          },
        ),
        AppButton(
          label: '월/연 선택',
          expand: false,
          onPressed: () async {
            final date = await showAppDatePicker(
              context: context,
              initial: DateTime.now(),
              mode: AppDatePickerMode.monthYear,
            );
            _setLog('선택한 월: $date');
          },
        ),
      ],
    );
  }

  Widget _switchDemo() {
    return Row(
      children: [
        AppSwitch(value: _switchValue, onChanged: (v) => setState(() => _switchValue = v)),
        const SizedBox(width: 24),
        AppCheckmark(checked: _checked, onChanged: (v) => setState(() => _checked = v)),
      ],
    );
  }

  Widget _segmentedDemo() {
    return AppSegmentedControl<String>(
      value: _segment,
      options: const [
        AppSegmentedOption(value: 'male', label: '남'),
        AppSegmentedOption(value: 'female', label: '여'),
      ],
      onChanged: (v) => setState(() => _segment = v),
    );
  }

  Widget _toastDemo() {
    return Wrap(
      spacing: 8,
      children: [
        AppButton(
          label: 'Info 토스트',
          expand: false,
          onPressed: () => AppToast.show(context, '정보 토스트입니다.'),
        ),
        AppButton(
          label: 'Success 토스트',
          expand: false,
          onPressed: () => AppToast.show(context, '완료되었습니다.', type: AppToastType.success),
        ),
        AppButton(
          label: 'Error 토스트',
          expand: false,
          onPressed: () => AppToast.show(context, '오류가 발생했습니다.', type: AppToastType.error),
        ),
      ],
    );
  }

  Widget _glassDemo() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.success]),
        borderRadius: AppRadius.borderRadius(AppRadius.lg),
      ),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: GlassSurface(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: const Text('Glass', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _navBarDemo() {
    return Column(
      children: [
        const AppNavBar(title: '내비게이션 바', showBackButton: false),
        const SizedBox(height: 8),
        const AppNavBar(title: 'Large Title', showBackButton: false, largeTitle: true),
      ],
    );
  }

  Widget _groupedSectionDemo() {
    return AppGroupedSection(
      header: '설정',
      children: [
        AppListTile(title: '알람 설정', showChevron: true, onTap: () => _setLog('알람 설정 탭')),
        AppListTile(title: '로그아웃', destructive: true, onTap: () => _setLog('로그아웃 탭')),
      ],
    );
  }

  Widget _swipeActionsDemo() {
    return AppSwipeActions(
      itemKey: const ValueKey('demo-swipe'),
      onDelete: () => _setLog('스와이프 삭제됨'),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: const Text('왼쪽으로 스와이프해서 삭제'),
      ),
    );
  }
}
