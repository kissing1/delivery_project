import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/page/login.dart';

/// Splash เปิดแอปแบบธีมเดลิเวอรี่ ZapGo
class AnimatedSplash extends StatefulWidget {
  final int? userIdSender; // เผื่อส่งค่าไปหน้าแรก
  const AnimatedSplash({super.key, this.userIdSender});

  @override
  State<AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<AnimatedSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  static const kGreen = Color(0xFF2ECC71);
  static const _logoAsset = 'assets/images/img_1_cropped.png';

  @override
  void initState() {
    super.initState();

    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _scale = Tween<double>(
      begin: .85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));
    _slide = Tween<Offset>(
      begin: const Offset(0, .08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

    _c.forward();

    // precache รูปเพื่อให้ขึ้นไว ไม่กระพริบ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage(_logoAsset), context);
    });

    // พักจอ splash สั้น ๆ แล้วไปหน้าแรก
    Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // พื้นหลังไล่เฉดนุ่ม ๆ โทนเดลิเวอรี่
          Positioned.fill(
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Color(0xFFF7FAF7)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // โลโก้ + ชื่อแบรนด์ + แถบโหลด (ใส่อนิเมชัน)
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // โลโก้ในกรอบวงกลม + เงานุ่ม
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.08),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: Image.asset(
                              _logoAsset,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.local_shipping_rounded,
                                size: 56,
                                color: kGreen,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ชื่อแบรนด์
                      const Text(
                        'ZapGo',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: kGreen,
                          letterSpacing: .3,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Progress bar เล็ก ๆ
                      Container(
                        width: 160,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedBuilder(
                            animation: _c,
                            builder: (_, __) {
                              final w = 160 * (_c.value.clamp(0.2, 1.0));
                              return Container(
                                width: w,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: kGreen,
                                  borderRadius: BorderRadius.circular(99),
                                  boxShadow: [
                                    BoxShadow(
                                      color: kGreen.withOpacity(.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // แท็กไลน์ล่าง
          Positioned(
            bottom: 28,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: .6,
              child: Text(
                'Deliver with care',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black.withOpacity(.45)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
