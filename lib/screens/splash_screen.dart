import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _startAnimation = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _startAnimation = true);
    });

    _navigateToNext();
  }

  void _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 4000));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    final route = session != null ? const HomeScreen() : const LoginScreen();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => route),
    );
  }

  Widget _buildAnimatedPiece({
    required Widget child,
    required double startX,
    required double startY,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: _startAnimation ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutExpo,
      builder: (context, value, child) {
        final currentX = startX * (1 - value);
        final currentY = startY * (1 - value);

        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(currentX, currentY),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFF121417);
    const double logoSize = 300.0;

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: SizedBox(
          width: logoSize,
          height: logoSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. القطعة العلوية
              _buildAnimatedPiece(
                startX: 0,
                startY: -150,
                child: Transform.translate(
                  offset: const Offset(0, -2), // الفاصل الأسود الصغير
                  child: SvgPicture.string(
                    '''
                    <svg viewBox="0 0 500 500" xmlns="http://www.w3.org/2000/svg">
                      <path fill="#FF7A00" d="M390 120H180L130 170V268L196 232V216L226 186H390Z"/>
                    </svg>
                    ''',
                    width: logoSize,
                  ),
                ),
              ),

              // 2. القطعة السفلية
              _buildAnimatedPiece(
                startX: 0,
                startY: 150,
                child: Transform.translate(
                  offset: const Offset(0, 2), // الفاصل الأسود الصغير
                  child: SvgPicture.string(
                    '''
                    <svg viewBox="0 0 500 500" xmlns="http://www.w3.org/2000/svg">
                      <path fill="#FF7A00" d="M130 276V330L180 380H390V314H226L196 284V240Z"/>
                    </svg>
                    ''',
                    width: logoSize,
                  ),
                ),
              ),

              // 3. الذراع الفولاذية (البيضة)
              _buildAnimatedPiece(
                startX: 150,
                startY: 0,
                child: Transform.translate(
                  // 👈 التعديل هنا: رجعناها لليسار لتصير 0 عشان تطابق الحافة السفلية
                  offset: const Offset(0, 0),
                  child: SvgPicture.string(
                    '''
                    <svg viewBox="0 0 500 500" xmlns="http://www.w3.org/2000/svg">
                      <path fill="#EFEDE8" d="M298 232H390V308H324V290H270V260Z"/>
                    </svg>
                    ''',
                    width: logoSize,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
