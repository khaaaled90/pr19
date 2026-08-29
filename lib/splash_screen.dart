import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'HomeScreen.dart';
import 'dart:async'; // 👈 أضف هذا السطر في أعلى الملف

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _cardAnim;
  late Animation<double> _wifiAnim;
  late Animation<double> _badgeAnim;

  @override
  void initState() {
    super.initState();
    // إعدادات الأنيميشن
    _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
    );

    _cardAnim = CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
    );

    _wifiAnim = CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
    );

    _badgeAnim = CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.65, 1.0, curve: Curves.elasticOut),
    );

    _controller.forward();

    // 🟢 الأسلوب الأفضل والأمن للانتقال بعد 2.5 ثانية:
    Future.delayed(const Duration(milliseconds: 2500), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
        );
    });
    // الانتقال للشاشة الرئيسية بعد انتهاء الأنيميشن (مثلاً بعد 2.5 ثانية)
    /*Timer(const Duration(milliseconds: 2500), () {
        if (mounted) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(
            builder: (context) => const MainNavigationScreen(), // استبدل HomeScreen باسم واجهتك الرئيسية
            ),
        );
        }
    });*/
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              size: const Size(320, 320),
              painter: SvgLogoPainter(
                cardProgress: _cardAnim.value,
                wifiProgress: _wifiAnim.value,
                badgeProgress: _badgeAnim.value,
              ),
            );
          },
        ),
      ),
    );
  }
}

class SvgLogoPainter extends CustomPainter {
  final double cardProgress;
  final double wifiProgress;
  final double badgeProgress;

  SvgLogoPainter({
    required this.cardProgress,
    required this.wifiProgress,
    required this.badgeProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 512;
    
    // 1. هالة الإضاءة خلف الشبكة
    final Paint glowPaint = Paint()
      ..color = const Color(0xFF0284C7).withOpacity(0.15 * wifiProgress)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(Offset(256 * scale, 200 * scale), 140 * scale, glowPaint);

    // 2. رسم كرت الشبكة (MikroTik Voucher Card)
    if (cardProgress > 0) {
      canvas.save();
      // تحريك ونقل الكرت
      canvas.translate(256 * scale, 270 * scale);
      canvas.scale(cardProgress);
      canvas.rotate(-6 * math.pi / 180);
      canvas.translate(-256 * scale, -270 * scale);

      // جسم الكرت والتدرج
      final Rect cardRect = Rect.fromLTWH(96 * scale, 170 * scale, 320 * scale, 200 * scale);
      final Paint cardPaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(cardRect);

      // ظل الكرت
      final Path cardPath = Path()
        ..addRRect(RRect.fromRectAndRadius(cardRect, Radius.circular(22 * scale)));
      canvas.drawShadow(cardPath, Colors.black, 14 * scale, false);
      canvas.drawPath(cardPath, cardPaint);

      // خطوط الشبكة داخل الكرت
      final Paint linePaint1 = Paint()
        ..color = const Color(0xFF60A5FA).withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * scale;
      final Path linePath1 = Path()
        ..moveTo(96 * scale, 230 * scale)
        ..quadraticBezierTo(256 * scale, 200 * scale, 416 * scale, 250 * scale);
      canvas.drawPath(linePath1, linePaint1);

      final Paint linePaint2 = Paint()
        ..color = const Color(0xFF34D399).withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * scale;
      final Path linePath2 = Path()
        ..moveTo(96 * scale, 260 * scale)
        ..quadraticBezierTo(256 * scale, 230 * scale, 416 * scale, 280 * scale);
      canvas.drawPath(linePath2, linePaint2);

      // شريط الـ PIN الأبيض
      final Rect pinRect = Rect.fromLTWH(126 * scale, 295 * scale, 160 * scale, 40 * scale);
      final Paint pinPaint = Paint()..color = Colors.white.withOpacity(0.95);
      canvas.drawRRect(RRect.fromRectAndRadius(pinRect, Radius.circular(8 * scale)), pinPaint);

      // نقاط الـ PIN
      final Paint dotPaint = Paint()..color = const Color(0xFF1E293B);
      canvas.drawCircle(Offset(150 * scale, 315 * scale), 5 * scale, dotPaint);
      canvas.drawCircle(Offset(170 * scale, 315 * scale), 5 * scale, dotPaint);
      canvas.drawCircle(Offset(190 * scale, 315 * scale), 5 * scale, dotPaint);
      canvas.drawCircle(Offset(210 * scale, 315 * scale), 5 * scale, dotPaint);

      // نص الـ PIN
      TextSpan span = TextSpan(
        text: '88K',
        style: TextStyle(
          color: const Color(0xFF0F172A),
          fontSize: 18 * scale,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      );
      TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(230 * scale, 305 * scale));

      canvas.restore();
    }

    // 3. رسم إشارة الواي فاي (Wi-Fi Signal)
    if (wifiProgress > 0) {
      final Rect wifiRect = Rect.fromLTWH(186 * scale, 135 * scale, 140 * scale, 100 * scale);
      final Shader wifiShader = const LinearGradient(
        colors: [Color(0xFF38BDF8), Color(0xFF34D399)],
      ).createShader(wifiRect);

      final Paint wifiStroke = Paint()
        ..shader = wifiShader
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // القوس الخارجي
      if (wifiProgress > 0.6) {
        wifiStroke.strokeWidth = 12 * scale;
        final Path path1 = Path();
        path1.addArc(Rect.fromCircle(center: Offset(256 * scale, 220 * scale), radius: 90 * scale), math.pi * 1.25, math.pi * 0.5 * wifiProgress);
        canvas.drawPath(path1, wifiStroke);
      }

      // القوس الأوسط
      if (wifiProgress > 0.3) {
        wifiStroke.strokeWidth = 10 * scale;
        final Path path2 = Path();
        path2.addArc(Rect.fromCircle(center: Offset(256 * scale, 220 * scale), radius: 60 * scale), math.pi * 1.25, math.pi * 0.5 * wifiProgress);
        canvas.drawPath(path2, wifiStroke);
      }

      // القوس الداخلي
      wifiStroke.strokeWidth = 8 * scale;
      final Path path3 = Path();
      path3.addArc(Rect.fromCircle(center: Offset(256 * scale, 220 * scale), radius: 30 * scale), math.pi * 1.25, math.pi * 0.5 * wifiProgress);
      canvas.drawPath(path3, wifiStroke);

      // نقطة البث
      final Paint dotFill = Paint()
        ..shader = wifiShader
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(256 * scale, 220 * scale), 8 * scale * wifiProgress, dotFill);
    }

    // 4. رسم دائرة الدفع وشارة الصح (CardPay Badge)
    if (badgeProgress > 0) {
      canvas.save();
      canvas.translate(355 * scale, 345 * scale);
      canvas.scale(badgeProgress);

      final Rect badgeRect = Rect.fromCircle(center: Offset.zero, radius: 48 * scale);
      final Paint badgePaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ).createShader(badgeRect);

      canvas.drawCircle(Offset.zero, 48 * scale, badgePaint);

      // سهم الشحن / الصح
      final Paint checkPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final Path checkPath = Path()
        ..moveTo(-20 * scale, 0)
        ..lineTo(-4 * scale, 16 * scale)
        ..lineTo(24 * scale, -12 * scale);

      canvas.drawPath(checkPath, checkPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant SvgLogoPainter oldDelegate) => true;
}