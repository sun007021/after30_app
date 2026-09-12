import 'package:after30/core/storage/onboarding_store.dart';
import 'package:after30/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.asset,
    required this.imageWidth,
    required this.imageHeight,
    required this.title,
    required this.subtitle,
  });

  final String asset;
  final double imageWidth;
  final double imageHeight;
  final String title;
  final String subtitle;
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const Color _primaryBlue = Color(0xFF1963FF);
  static const Color _subtitleGray = Color(0xFFA3A3A3);
  static const Color _dotInactive = Color(0xFFD9D9D9);

  static const _slides = [
    _OnboardingSlide(
      asset: 'assets/images/onboarding/onboarding1.png',
      imageWidth: 152,
      imageHeight: 199,
      title: '약, 이제 식후30분에게\n맡기세요.',
      subtitle: '복용 시간과 약 정보를 입력하면\n앱이 알아서 정리해드려요.',
    ),
    _OnboardingSlide(
      asset: 'assets/images/onboarding/onboarding2.png',
      imageWidth: 185,
      imageHeight: 192,
      title: '먹어야 할때, 딱 맞춰\n알려드릴게요.',
      subtitle: '바쁜 하루 속에서도 약 놓치는 일\n없도록 알림을 보내드려요.',
    ),
    _OnboardingSlide(
      asset: 'assets/images/onboarding/onboarding3.png',
      imageWidth: 184,
      imageHeight: 180,
      title: '잘 챙겼는지 한눈에\n확인하세요.',
      subtitle: '달력에서 복용 기록을 확인하고\n건강 습관을 차곡차곡 쌓아보세요.',
    ),
    _OnboardingSlide(
      asset: 'assets/images/onboarding/onboarding4.png',
      imageWidth: 208,
      imageHeight: 182,
      title: '혼자가 아니라,\n가족이 함께 챙겨요.',
      subtitle: '부모님, 아이, 배우자까지 서로의\n복약 상황을 함께 확인할 수 있어요.',
    ),
  ];

  final PageController _pageController = PageController();
  int _index = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onNext() async {
    if (_finishing) return;
    if (_index < _slides.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
      return;
    }
    await _goToLogin();
  }

  Future<void> _goToLogin() async {
    _finishing = true;
    await OnboardingStore.setCompleted();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (index) => setState(() => _index = index),
                  itemBuilder: (context, index) =>
                      _buildSlide(context, _slides[index]),
                ),
              ),
              _buildDots(context),
              SizedBox(height: Responsive.responsiveHeight(context, 24)),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.responsiveValue(context, 39),
                ),
                child: SizedBox(
                  height: Responsive.responsiveValue(context, 45),
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          Responsive.responsiveValue(context, 12),
                        ),
                      ),
                    ),
                    child: Text(
                      '다음',
                      style: TextStyle(
                        fontSize: Responsive.responsiveFontSize(context, 16),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: Responsive.responsiveHeight(context, 22)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlide(BuildContext context, _OnboardingSlide slide) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.responsiveValue(context, 40),
      ),
      child: Column(
        children: [
          const Spacer(flex: 5),
          Image.asset(
            slide.asset,
            width: Responsive.responsiveValue(context, slide.imageWidth),
            height: Responsive.responsiveValue(context, slide.imageHeight),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          SizedBox(height: Responsive.responsiveHeight(context, 32)),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontSize: Responsive.responsiveFontSize(context, 24),
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          SizedBox(height: Responsive.responsiveHeight(context, 9)),
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _subtitleGray,
              fontSize: Responsive.responsiveFontSize(context, 13),
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const Spacer(flex: 4),
        ],
      ),
    );
  }

  Widget _buildDots(BuildContext context) {
    final size = Responsive.responsiveValue(context, 8);
    final gap = Responsive.responsiveValue(context, 8);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_slides.length, (i) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: gap / 2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == _index ? _primaryBlue : _dotInactive,
            ),
          ),
        );
      }),
    );
  }
}
