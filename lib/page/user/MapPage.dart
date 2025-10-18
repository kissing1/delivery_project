import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng? _selectedPoint;

  // ===== THEME (Delivery Premium) =====
  static const _kBg = Color(0xFFF6FAF8);
  static const _kGreen = Color(0xFF32BD6C);
  static const _kGreenDark = Color(0xFF249B58);
  static const _kPink = Color(0xFFFF5C8A);
  static const _kInk = Color(0xFF101214);

  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // ===== Header: Gradient + brand =====
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              bottom: 16,
              left: 12,
              right: 12,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_kGreen, _kGreenDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  blurRadius: 14,
                  offset: Offset(0, 6),
                  color: Color(0x33000000),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ซ้าย/ขวา: โลโก้ตามเดิม
                Positioned(
                  left: 6,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                    tooltip: 'กลับ',
                  ),
                ),
                Positioned(
                  left: 56,
                  child: Image.asset(
                    "assets/images/img_2_cropped.png",
                    width: 36,
                  ),
                ),
                Positioned(
                  right: 56,
                  child: Image.asset(
                    "assets/images/img_2_cropped.png",
                    width: 36,
                  ),
                ),
                // ตรงกลาง: แบรนด์
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      "เลือกพิกัดสำหรับที่อยู่",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Delivery • Premium",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ===== Map =====
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(16.246373, 103.251827),
                    initialZoom: 14,
                    onTap: (tapPosition, point) {
                      setState(() => _selectedPoint = point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.flutter_application_1',
                    ),
                    if (_selectedPoint != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedPoint!,
                            width: 70,
                            height: 70,
                            child: _PulsePin(controller: _pulseCtrl),
                          ),
                        ],
                      ),
                  ],
                ),

                // ===== ชิปบอกพิกัดที่เลือก (ขวาบน) =====
                Positioned(
                  top: 16,
                  right: 12,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _selectedPoint == null
                        ? _glassHint("แตะบนแผนที่เพื่อเลือกพิกัด")
                        : _infoChip(
                            icon: Icons.location_on_rounded,
                            label: "พิกัดที่เลือก",
                            value:
                                "${_selectedPoint!.latitude.toStringAsFixed(6)}, "
                                "${_selectedPoint!.longitude.toStringAsFixed(6)}",
                          ),
                  ),
                ),

                // ===== การ์ดคำแนะนำด้านล่าง (เหนือปุ่ม) =====
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 94,
                  child: _tipCard(
                    _selectedPoint == null
                        ? "แตะบนแผนที่เพื่อปักหมุดตำแหน่งที่ต้องการจัดส่ง"
                        : "ตรวจสอบพิกัดแล้วกดยืนยันเพื่อส่งกลับหน้าก่อนหน้า",
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // ===== ปุ่มยืนยัน (Extended) =====
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: MediaQuery.of(context).size.width - 32,
        child: FloatingActionButton.extended(
          heroTag: "confirmLocationFAB",
          onPressed: () {
            if (_selectedPoint != null) {
              Navigator.pop(context, {
                "lat": _selectedPoint!.latitude,
                "lng": _selectedPoint!.longitude,
              });
            } else {
              Navigator.pop(context);
            }
          },
          backgroundColor: _kPink,
          elevation: 8,
          icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
          label: const Text(
            "ยืนยันพิกัด",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: .3,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ===== UI helpers (หน้าตาเท่านั้น) =====

  Widget _glassHint(String text) {
    return Container(
      key: const ValueKey('hint'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.90),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(blurRadius: 12, color: Colors.black.withOpacity(.08)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.touch_app_rounded, size: 18, color: _kGreenDark),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700, color: _kInk),
          ),
        ],
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      key: const ValueKey('coords'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(blurRadius: 12, color: Colors.black.withOpacity(.10)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: _kGreenDark),
          const SizedBox(width: 6),
          Text(
            "$label: ",
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: _kInk, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _tipCard(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12.withOpacity(.06)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(.08),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _kGreen.withOpacity(.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.info_rounded, color: _kGreenDark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _kInk,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ===== Pulse marker (สวย ๆ แบบพรีเมียม) =====
class _PulsePin extends StatelessWidget {
  final AnimationController controller;
  const _PulsePin({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = controller.value; // 0..1
        final outer = 24.0 + 10 * t;
        final opacity = (1 - t) * .6 + .2;

        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: outer,
              height: outer,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withOpacity(opacity),
              ),
            ),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.black12,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 12,
                    spreadRadius: 2,
                    color: Colors.black.withOpacity(.18),
                  ),
                ],
              ),
            ),
            const Icon(Icons.location_pin, color: Colors.red, size: 44),
          ],
        );
      },
    );
  }
}
