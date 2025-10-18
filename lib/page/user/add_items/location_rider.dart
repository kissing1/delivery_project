import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/model/responses/overview_rider_get_res.dart';
import 'package:flutter_application_1/config/config.dart';

class LocationRider extends StatefulWidget {
  final int riderId;
  const LocationRider({super.key, required this.riderId});

  @override
  State<LocationRider> createState() => _LocationRiderState();
}

class _LocationRiderState extends State<LocationRider>
    with TickerProviderStateMixin {
  final MapController _map = MapController();
  StreamSubscription<DocumentSnapshot>? _riderStream;
  Timer? _checkTimer;

  LatLng? _rider;
  LatLng? _receiver;
  double _bearingDeg = 0;

  List<LatLng> _route = [];
  List<LatLng> _remaining = [];
  final _dist = const Distance();

  bool _mapReady = false;
  bool _loading = true;
  bool _popupShown = false;

  // ==== THEME ====
  static const _kGreen = Color(0xFF32BD6C);
  static const _kGreenDark = Color(0xFF249B58);
  static const _kBg = Color(0xFFF6FAF8);

  // ==== Animations ====
  late final AnimationController _pulseCtrl; // ผู้รับ pulse
  late final AnimationController _barCtrl; // เฮดเดอร์/พาเนลเล็กน้อย

  bool _showInfoPanel = true;
  double get _panelHeight => 150;

  // ==== NEW: toggle เปิด/ปิด bottom panel ====
  bool _isPanelOpen = false; // เริ่ม "ปิด"
  void _togglePanel() => setState(() => _isPanelOpen = !_isPanelOpen);

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _barCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();

    _fetchInitialPosition();

    // 🕒 ตั้ง Timer เช็ก delivery_id ทุก 5 วิ
    _checkTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkIfDeliveryFinished();
    });
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _riderStream?.cancel();
    _pulseCtrl.dispose();
    _barCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialPosition() async {
    try {
      final cfg = await Configuration.getConfig();
      final baseUrl = cfg["apiEndpoint"];
      final url = Uri.parse("$baseUrl/riders/overview/${widget.riderId}");

      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = overviewRiderGetResFromJson(res.body);

        // ✅ ถ้า delivery_id เป็น null ตอนเปิดหน้าครั้งแรก
        if (data.deliveryId == null) {
          _showDeliveryCompletePopup();
          return;
        }

        _rider = LatLng(data.riderLat, data.riderLng);
        _receiver = LatLng(
          (data.receiverLat as num).toDouble(),
          (data.receiverLng as num).toDouble(),
        );

        await _fetchRouteFromOSRM();
        await _initFirestoreListener();
      } else {
        debugPrint("❌ overview error: ${res.statusCode} ${res.body}");
      }
    } catch (e) {
      debugPrint("❌ overview exception: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 🕒 เช็กซ้ำว่ามีการ finish หรือยัง
  Future<void> _checkIfDeliveryFinished() async {
    if (_popupShown) return; // ✅ กัน popup เด้งซ้ำ
    try {
      final cfg = await Configuration.getConfig();
      final baseUrl = cfg["apiEndpoint"];
      final url = Uri.parse("$baseUrl/riders/overview/${widget.riderId}");

      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = overviewRiderGetResFromJson(res.body);
        if (data.deliveryId == null) {
          _showDeliveryCompletePopup();
        }
      }
    } catch (e) {
      debugPrint("❌ checkIfDeliveryFinished exception: $e");
    }
  }

  Future<void> _initFirestoreListener() async {
    final docRef = FirebaseFirestore.instance
        .collection('rider_location')
        .doc(widget.riderId.toString());

    _riderStream = docRef.snapshots().listen((snapshot) async {
      if (!snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>;

      final lat = (data['lat'] as num).toDouble();
      final lng = (data['lng'] as num).toDouble();
      final next = LatLng(lat, lng);

      if (_rider != null) {
        _bearingDeg = _bearing(_rider!, next);
      }
      _rider = next;
      _updateRouteConsumption(next);

      if (mounted && _mapReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _map.move(next, _map.camera.zoom);
        });
        setState(() {});
      }
    });
  }

  Future<void> _fetchRouteFromOSRM() async {
    if (_rider == null || _receiver == null) return;

    final url =
        'https://router.project-osrm.org/route/v1/driving/'
        '${_rider!.longitude},${_rider!.latitude};'
        '${_receiver!.longitude},${_receiver!.latitude}'
        '?overview=full&geometries=geojson';

    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final coords = data['routes'][0]['geometry']['coordinates'] as List;
      _route = coords
          .map(
            (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
          )
          .toList();
      _remaining = List.from(_route);
      if (mounted) setState(() {});
    }
  }

  void _updateRouteConsumption(LatLng current) {
    if (_route.isEmpty) return;
    int idx = _nearestRouteIndex(current).clamp(0, _route.length - 1);
    _remaining = _route.sublist(idx);
    if (_remaining.isNotEmpty) {
      _remaining[0] = current;
    } else {
      _remaining = [current];
    }
  }

  int _nearestRouteIndex(LatLng p) {
    int bestIdx = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < _route.length; i++) {
      final d = _dist(p, _route[i]);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  double _bearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final b = math.atan2(y, x);
    return (b * 180 / math.pi + 360) % 360;
  }

  /// ✅ Popup "ขนส่งเสร็จสิ้น"
  void _showDeliveryCompletePopup() {
    if (!mounted || _popupShown) return;
    _popupShown = true;

    final snackBar = SnackBar(
      duration: const Duration(seconds: 3),
      backgroundColor: _kGreen,
      content: Row(
        children: const [
          Icon(Icons.check_circle, color: Colors.white),
          SizedBox(width: 10),
          Text(
            "ขนส่งเสร็จสิ้น ✅",
            style: TextStyle(
              fontSize: 16,
              fontFamily: "Poppins",
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.pop(context);
    });
  }

  // ===== Helpers UI =====
  double _distanceLeftMeters() {
    if (_remaining.length < 2) return 0;
    double m = 0;
    for (var i = 0; i < _remaining.length - 1; i++) {
      m += _dist(_remaining[i], _remaining[i + 1]);
    }
    return m; // meters
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return "${(meters / 1000).toStringAsFixed(2)} กม.";
    }
    return "${meters.toStringAsFixed(0)} ม.";
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_rider == null || _receiver == null) {
      return const Scaffold(body: Center(child: Text("ไม่พบตำแหน่ง")));
    }

    final distanceLeft = _formatDistance(_distanceLeftMeters());

    // ความสูงเวลากาง/พับ
    final double openPanelHeight =
        (MediaQuery.of(context).size.height * 0.40) +
        MediaQuery.of(context).padding.bottom;
    final double collapsedHeight =
        24 + MediaQuery.of(context).padding.bottom; // แถบเล็กตอนพับ

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // ===== Map =====
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _rider!,
              initialZoom: 17,
              onMapReady: () => setState(() => _mapReady = true),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flutter_application_1',
              ),

              // เส้นทางที่เหลือ: เขียว + เงา
              if (_remaining.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _remaining,
                      strokeWidth: 8,
                      color: _kGreen.withOpacity(.85),
                    ),
                    Polyline(
                      points: _remaining,
                      strokeWidth: 12,
                      color: _kGreen.withOpacity(.18),
                    ),
                  ],
                ),

              // Markers
              MarkerLayer(
                markers: [
                  // Rider marker (หมุนตามเข็มทิศ + เงา)
                  Marker(
                    point: _rider!,
                    width: 64,
                    height: 64,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
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
                        Transform.rotate(
                          angle: _bearingDeg * (math.pi / 180),
                          child: Image.asset(
                            'assets/images/rider_icon.png',
                            width: 56,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Receiver marker (Pulse)
                  Marker(
                    point: _receiver!,
                    width: 70,
                    height: 70,
                    child: _PulsePin(controller: _pulseCtrl),
                  ),
                ],
              ),
            ],
          ),

          // ===== Header (gradient) =====
          SafeArea(
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _barCtrl, curve: Curves.easeOut),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_kGreen, _kGreenDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 12,
                            color: Colors.black.withOpacity(.15),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 10,
                      ),
                      child: Row(
                        children: [
                          _chipIcon(
                            icon: Icons.arrow_back,
                            onTap: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.delivery_dining,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  "ติดตามไรเดอร์",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: "Poppins",
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // ==== NEW: ปุ่มเปิด/ปิด bottom panel ====
                          _chipIcon(
                            icon: _isPanelOpen
                                ? Icons.expand_more_rounded
                                : Icons.expand_less_rounded,
                            onTap: _togglePanel,
                          ),
                          const SizedBox(width: 6),

                          _chipIcon(
                            icon: Icons.my_location,
                            onTap: () {
                              if (_rider != null && _mapReady) {
                                _map.move(_rider!, _map.camera.zoom);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ===== Info chips top-right =====
          Positioned(
            top: MediaQuery.of(context).padding.top + 72,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _glassChip(
                  icon: Icons.straighten,
                  text: "เหลือ: $distanceLeft",
                ),
                const SizedBox(height: 8),
                _glassChip(
                  icon: Icons.explore,
                  text: "มุ่ง: ${_bearingDeg.toStringAsFixed(0)}°",
                ),
              ],
            ),
          ),

          // ===== Bottom info panel (พับ/กางได้) =====
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: 0,
            height: _isPanelOpen ? openPanelHeight : collapsedHeight,
            child: _bottomPanel(
              distanceLeft,
              maxHeight: MediaQuery.of(context).size.height * 0.40,
              isOpen: _isPanelOpen,
              onToggle: _togglePanel,
            ),
          ),
        ],
      ),
    );
  }

  // ========= UI small parts =========
  Widget _chipIcon({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _glassChip({required IconData icon, required String text}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white),
            boxShadow: [
              BoxShadow(blurRadius: 10, color: Colors.black.withOpacity(.06)),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: _kGreenDark),
              const SizedBox(width: 6),
              Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  fontFamily: "Poppins",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom panel รองรับโหมดพับ/กาง
  Widget _bottomPanel(
    String distanceLeft, {
    required double maxHeight,
    required bool isOpen,
    required VoidCallback onToggle,
  }) {
    final padBottom = MediaQuery.of(context).padding.bottom;

    // โหมดพับ: โชว์แค่แถบจับ
    if (!isOpen) {
      return GestureDetector(
        onTap: onToggle,
        child: Container(
          padding: EdgeInsets.only(bottom: padBottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            boxShadow: [BoxShadow(blurRadius: 14, color: Color(0x1F000000))],
          ),
          child: Center(
            child: Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      );
    }

    // โหมดกาง: แสดงข้อมูล
    return Container(
      padding: EdgeInsets.fromLTRB(14, 12, 14, 14 + padBottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [
          BoxShadow(blurRadius: 14, color: Colors.black.withOpacity(.12)),
        ],
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: [
              // แถบจับ + ปุ่มพับ
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: onToggle,
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'ซ่อนแผงข้อมูล',
                    icon: const Icon(Icons.expand_more_rounded),
                    onPressed: onToggle,
                  ),
                ],
              ),
              const SizedBox(height: 6),

              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: _showInfoPanel
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Column(
                  children: [
                    Row(
                      children: [
                        _miniLegend(color: _kGreen, label: "เส้นทาง"),
                        const SizedBox(width: 12),
                        _miniLegend(color: Colors.red, label: "ปลายทาง"),
                        const Spacer(),
                        _miniLegend(color: Colors.black26, label: "ไรเดอร์"),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _infoTile(
                          icon: Icons.flag,
                          title: "ปลายทาง",
                          value:
                              "${_receiver!.latitude.toStringAsFixed(5)}, ${_receiver!.longitude.toStringAsFixed(5)}",
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _infoTile(
                          icon: Icons.route,
                          title: "ระยะทางคงเหลือ",
                          value: distanceLeft,
                        ),
                        const SizedBox(width: 12),
                        _infoTile(
                          icon: Icons.explore,
                          title: "ทิศทาง",
                          value: "${_bearingDeg.toStringAsFixed(0)}°",
                        ),
                      ],
                    ),
                  ],
                ),
                secondChild: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniLegend({required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12.withOpacity(.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _kGreen.withOpacity(.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: _kGreenDark),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===== Pulse marker for receiver =====
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
            const Icon(Icons.location_pin, color: Colors.red, size: 42),
          ],
        );
      },
    );
  }
}
