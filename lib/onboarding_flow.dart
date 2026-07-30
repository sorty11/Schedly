import 'dart:ui';
import 'dart:ui' as dart_ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart';
import 'theme/theme.dart';
import 'services/authentication_service.dart';
import 'services/crash_reporting_service.dart';
import 'widgets/app_dialogs.dart';
import 'forgot_password_page.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PROJECT PHOENIX: Onboarding & Auth Flow
// ═══════════════════════════════════════════════════════════════════════════════

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> with TickerProviderStateMixin {
  late AnimationController _timeline;
  late AnimationController _loginCtrl;
  late AnimationController _bgCtrl;

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _emailFocus = FocusNode();

  bool _loading = false;
  bool _obscure = true;
  bool _isLogin = true;
  bool _showMobileLogin = false;

  // Timeline (3.0s)
  static const double _kStars0 = 0.00;
  static const double _kStars1 = 0.10; // 0-300ms
  static const double _kStroke0 = 0.10;
  static const double _kStroke1 = 0.30; // 300-900ms
  static const double _kTypo0 = 0.40;
  static const double _kTypo1 = 0.566; // 1200-1700ms
  static const double _kSettle0 = 0.566;
  static const double _kSettle1 = 0.733; // 1700-2200ms
  static const double _kSub0 = 0.733;
  static const double _kSub1 = 0.833; // 2200-2500ms
  static const double _kCta0 = 0.833;
  static const double _kCta1 = 1.00; // 2500-3000ms

  @override
  void initState() {
    super.initState();
    _timeline = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
    _loginCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timeline.forward();
    });
  }

  @override
  void dispose() {
    _timeline.dispose();
    _loginCtrl.dispose();
    _bgCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  double _kf(double t, double s, double e) {
    if (t <= s) return 0;
    if (t >= e) return 1;
    return Curves.easeInOutCubic.transform((t - s) / (e - s));
  }

  void _goToLogin() {
    HapticFeedback.lightImpact();
    setState(() => _showMobileLogin = true);
    _loginCtrl.forward().then((_) => _emailFocus.requestFocus());
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final email = _emailCtrl.text.trim();
      final pass = _passCtrl.text.trim();
      if (_isLogin) {
        await AuthenticationService.signInWithEmailAndPassword(email: email, password: pass);
      } else {
        await AuthenticationService.registerWithEmailAndPassword(email: email, password: pass);
      }
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StartupRouter()));
    } catch (e, st) {
      if (!mounted) return;
      CrashReportingService.logError(e, st, reason: 'Auth');
      AppDialogs.showError(
        context: context,
        title: _isLogin ? 'Sign In Failed' : 'Registration Failed',
        message: e.toString().replaceAll(RegExp(r'\[.*\]\s*'), ''),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ));

    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF030712), Color(0xFF0F172A)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([_bgCtrl, _timeline]),
                builder: (ctx, _) {
                  final starOpacity = _kf(_timeline.value, _kStars0, _kStars1);
                  return CustomPaint(painter: _StarAndWavePainter(_bgCtrl.value, starOpacity));
                },
              ),
            ),
            if (isDesktop)
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: _buildBranding(context, true),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _timeline,
                        builder: (ctx, _) {
                          final ctaProg = _kf(_timeline.value, _kCta0, _kCta1);
                          return _buildLoginCard(context, ctaProg);
                        },
                      ),
                    ),
                  ),
                  const Spacer(flex: 1),
                ],
              )
            else
              Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: _buildBranding(context, false),
                  ),
                  if (_showMobileLogin)
                    AnimatedBuilder(
                      animation: _loginCtrl,
                      builder: (ctx, _) {
                        final loginT = Curves.easeInOutCubic.transform(_loginCtrl.value);
                        return Positioned(
                          left: 0, right: 0, bottom: 0,
                          child: Opacity(
                            opacity: loginT,
                            child: Transform.translate(
                              offset: Offset(0, 60 * (1 - loginT)),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 40),
                                child: _buildLoginCard(context, 1.0),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranding(BuildContext context, bool isDesktop) {
    return AnimatedBuilder(
      animation: Listenable.merge([_timeline, _loginCtrl]),
      builder: (ctx, _) {
        final t = _timeline.value;
        final loginT = Curves.easeInOutCubic.transform(_loginCtrl.value);

        final strokeProg = _kf(t, _kStroke0, _kStroke1);
        final typoProg = _kf(t, _kTypo0, _kTypo1);
        final settleProg = _kf(t, _kSettle0, _kSettle1);
        final subProg = _kf(t, _kSub0, _kSub1);
        final ctaProg = _kf(t, _kCta0, _kCta1);

        final glowIntro = _kf(t, 0.3, 0.4);
        final glowPulse = math.sin(settleProg * math.pi) * 0.4;
        final glowProg = glowIntro + glowPulse;

        final moveUpOffset = isDesktop ? 0.0 : -loginT * 180.0;
        final opacityOut = isDesktop ? 1.0 : (1.0 - loginT);

        final tracking = dart_ui.lerpDouble(1.0, -0.5, Curves.easeOutCubic.transform(settleProg))!;

        return Transform.translate(
          offset: Offset(0, moveUpOffset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 42, height: 56,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _SRevealPainter(
                          strokeProgress: strokeProg,
                          glowOpacity: glowProg,
                        ),
                      ),
                    ),
                  ),
                  if (typoProg > 0)
                    ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: Curves.easeOutCubic.transform(typoProg),
                        child: Text(
                          'chedly',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 46,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: tracking,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Opacity(
                opacity: subProg,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - subProg)),
                  child: Text('Your Academic Companion',
                      style: TextStyle(
                          fontFamily: 'Inter', fontSize: 15,
                          fontWeight: FontWeight.w400, color: const Color(0xFF9CA3AF),
                          letterSpacing: 0.5)),
                ),
              ),
              if (!isDesktop) ...[
                const SizedBox(height: 48),
                Opacity(
                  opacity: ctaProg * opacityOut,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - ctaProg)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: SizedBox(
                        width: double.infinity, height: 52,
                        child: _primaryButton(
                          label: 'Get Started',
                          onPressed: ctaProg > 0.8 ? _goToLogin : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoginCard(BuildContext ctx, double opacity) {
    if (opacity <= 0) return const SizedBox.shrink();

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, 20 * (1 - opacity)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 40, spreadRadius: -10, offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_isLogin ? 'Welcome back' : 'Create account',
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 28,
                            fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5)),
                    const SizedBox(height: 6),
                    Text(_isLogin ? 'Sign in to continue to Schedly.' : 'Create your Schedly account.',
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF9CA3AF))),
                    const SizedBox(height: 32),
                    _glassField(
                      controller: _emailCtrl, focusNode: _emailFocus,
                      hint: 'Email address', icon: Icons.mail_outline_rounded,
                      keyboard: TextInputType.emailAddress,
                      validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
                    ),
                    const SizedBox(height: 16),
                    _glassField(
                      controller: _passCtrl, hint: 'Password',
                      icon: Icons.lock_outline_rounded, obscure: _obscure,
                      suffix: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => setState(() => _obscure = !_obscure),
                          child: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: const Color(0xFF9CA3AF), size: 18),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (!_isLogin && v.length < 8) return 'Min 8 characters';
                        return null;
                      },
                    ),
                    if (_isLogin) ...[
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())),
                            child: const Text('Forgot password?',
                                style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                                    fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF))),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    _primaryButton(
                      label: _isLogin ? 'Sign In' : 'Continue',
                      onPressed: _loading ? null : _submit,
                      isLoading: _loading,
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_isLogin ? "Don't have an account? " : 'Already have an account? ',
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF9CA3AF))),
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () { HapticFeedback.selectionClick(); setState(() => _isLogin = !_isLogin); },
                              child: Text(_isLogin ? 'Sign Up' : 'Sign In',
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13,
                                      fontWeight: FontWeight.w600, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _primaryButton({required String label, required VoidCallback? onPressed, bool isLoading = false}) {
    return MouseRegion(
      cursor: onPressed == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: double.infinity, height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                blurRadius: 20, offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.5),
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ),
    );
  }

  Widget _glassField({
    required TextEditingController controller,
    required String hint, required IconData icon,
    FocusNode? focusNode, bool obscure = false,
    Widget? suffix, String? Function(String?)? validator,
    TextInputType? keyboard,
  }) {
    return TextFormField(
      controller: controller, focusNode: focusNode,
      obscureText: obscure, validator: validator, keyboardType: keyboard,
      cursorColor: const Color(0xFF2563EB),
      style: const TextStyle(color: Colors.white, fontFamily: 'Inter', fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontFamily: 'Inter', fontSize: 14, color: const Color(0xFF9CA3AF).withValues(alpha: 0.6)),
        prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF030712).withValues(alpha: 0.4),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 0.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red.withValues(alpha: 0.4), width: 0.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1)),
        errorStyle: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.redAccent),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// S REVEAL
// ═══════════════════════════════════════════════════════════════════════════════

class _SRevealPainter extends CustomPainter {
  final double strokeProgress;
  final double glowOpacity;

  _SRevealPainter({required this.strokeProgress, required this.glowOpacity});

  static Path _createS(double height) {
    final h = height;
    final w = h * 0.52;
    final p = Path();
    p.moveTo(w * 0.38, -h * 0.44);
    p.cubicTo(w * 0.30, -h * 0.52, -w * 0.42, -h * 0.50, -w * 0.38, -h * 0.30);
    p.cubicTo(-w * 0.28, -h * 0.10, w * 0.42, h * 0.10, w * 0.36, h * 0.30);
    p.cubicTo(w * 0.30, h * 0.50, -w * 0.42, h * 0.52, -w * 0.38, h * 0.44);
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (strokeProgress <= 0) return;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final sPath = _createS(size.height * 0.9);

    canvas.save();
    canvas.translate(cx, cy);

    // Glow
    if (glowOpacity > 0) {
      canvas.drawCircle(Offset.zero, size.height * 0.5, Paint()
        ..color = const Color(0xFF2563EB).withValues(alpha: glowOpacity * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 35));
    }

    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (strokeProgress < 1.0) {
      for (final m in sPath.computeMetrics()) {
        canvas.drawPath(m.extractPath(0, m.length * strokeProgress), strokePaint);
      }
    } else {
      canvas.drawPath(sPath, strokePaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SRevealPainter o) =>
      o.strokeProgress != strokeProgress || o.glowOpacity != glowOpacity;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BACKGROUND PAINTER (Stars + Waves)
// ═══════════════════════════════════════════════════════════════════════════════

class _StarAndWavePainter extends CustomPainter {
  final double t;
  final double globalOpacity;
  _StarAndWavePainter(this.t, this.globalOpacity);

  @override
  void paint(Canvas canvas, Size size) {
    if (globalOpacity <= 0) return;
    // 1. Blue waves at bottom
    final wavePaint = Paint()..style = PaintingStyle.stroke;
    for (int i = 0; i < 2; i++) {
      final path = Path();
      final amp = 30.0 + i * 20.0;
      final yBase = size.height * 0.85 + i * 20;
      final phase = t * math.pi * 2 + i * math.pi;
      
      path.moveTo(0, yBase);
      for (double x = 0; x <= size.width; x += 10) {
        final y = yBase + math.sin((x / size.width) * math.pi * 2 + phase) * amp;
        path.lineTo(x, y);
      }
      wavePaint.color = const Color(0xFF2563EB).withValues(alpha: (0.05 - i * 0.02) * globalOpacity);
      wavePaint.strokeWidth = 2.0 + i;
      canvas.drawPath(path, wavePaint);
    }
    
    // 2. Slow drifting stars
    final rng = math.Random(42);
    final starPaint = Paint();
    for (int i = 0; i < 40; i++) {
      final sx = rng.nextDouble() * size.width;
      final sy = rng.nextDouble() * size.height;
      final sizeStar = 0.5 + rng.nextDouble();
      final phase = rng.nextDouble() * math.pi * 2;
      
      final dx = math.sin(t * math.pi * 2 + phase) * 15;
      final dy = math.cos(t * math.pi * 2 + phase) * 15;
      final opacity = 0.1 + 0.4 * (0.5 + 0.5 * math.sin(t * math.pi * 4 + phase));
      
      starPaint.color = Colors.white.withValues(alpha: opacity * globalOpacity);
      canvas.drawCircle(Offset(sx + dx, sy + dy), sizeStar, starPaint);
    }
    
    // 3. Occasional shooting stars
    final tracks = [
      _Track(0.1, 0.15, size.width * 0.2, -50, size.width * 1.2, size.height * 0.4),
      _Track(0.6, 0.12, -50, size.height * 0.2, size.width * 0.8, size.height * 0.6),
    ];
    for (final tr in tracks) {
      final phase = (t - tr.start) % 1.0;
      if (phase >= 0 && phase <= tr.dur) {
        final p = phase / tr.dur;
        final x = tr.sx + (tr.ex - tr.sx) * p;
        final y = tr.sy + (tr.ey - tr.sy) * p;
        final tailX = tr.sx + (tr.ex - tr.sx) * math.max(0, p - 0.2);
        final tailY = tr.sy + (tr.ey - tr.sy) * math.max(0, p - 0.2);
        
        final grad = dart_ui.Gradient.linear(
          Offset(tailX, tailY), Offset(x, y),
          [Colors.transparent, Colors.white.withValues(alpha: 0.8 * globalOpacity)]
        );
        canvas.drawLine(Offset(tailX, tailY), Offset(x, y), Paint()..shader = grad..strokeWidth = 2);
        canvas.drawCircle(Offset(x,y), 2, Paint()..color = Colors.white.withValues(alpha: globalOpacity));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarAndWavePainter oldDelegate) => oldDelegate.t != t;
}

class _Track {
  final double start, dur, sx, sy, ex, ey;
  _Track(this.start, this.dur, this.sx, this.sy, this.ex, this.ey);
}
