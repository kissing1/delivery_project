import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui'; // สำหรับ BackdropFilter (ไม่กระทบระบบ, ไม่เกี่ยวกับ cache)

import 'package:flutter/material.dart';
import 'package:flutter_application_1/config/config.dart';
import 'package:flutter_application_1/model/responses/users_address_id_get_res.dart';
import 'package:flutter_application_1/model/requsts/accep_status_update_req.dart'; // ← model req
import 'package:flutter_application_1/model/responses/accep_status_update_res.dart'; // ← model res
import 'package:flutter_application_1/page/rider/delivery/go_receive_item.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

// สำหรับเลือกรูป + บีบอัด
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class RiderGosender extends StatefulWidget {
  final int addressId;
  final int riderId;
  final int deliveryid;

  const RiderGosender({
    super.key,
    required this.addressId,
    required this.riderId,
    required this.deliveryid,
  });

  @override
  State<RiderGosender> createState() => _RiderGosenderState();
}

class _RiderGosenderState extends State<RiderGosender>
    with WidgetsBindingObserver {
  final MapController mapController = MapController();
  StreamSubscription<Position>? _posSub;

  LatLng? riderLatLng; // พิกัดไรเดอร์ (จริง)
  LatLng? senderLatLng; // พิกัดผู้ส่ง (จาก API)

  bool _loading = true;
  bool _sending = false;
  final _dist = const Distance();
  String? _apiBase;

  // เส้นทางรวม + แยกเป็น “ผ่านแล้ว/คงเหลือ”
  List<LatLng> routePoints = [];
  List<LatLng> traversedPoints = [];
  List<LatLng> remainingPoints = [];

  // หมุน marker + คุมกล้อง
  double _bearingDeg = 0;
  DateTime _lastCameraMove = DateTime.fromMillisecondsSinceEpoch(0);

  // ---- รูปถ่าย/แกลเลอรี ----
  final ImagePicker _picker = ImagePicker();
  String? _imageBase64;

  // ==== THEME (Delivery) ====
  static const kBg = Color(0xFFF6FAF8);
  static const kGreen = Color(0xFF32BD6C);
  static const kGreenDark = Color(0xFF249B58);
  static const kPink = Color(0xFFFF5C8A);
  static const kInk = Color(0xFF111418);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    Configuration.getConfig().then((cfg) {
      if (!mounted) return;
      setState(() => _apiBase = (cfg['apiEndpoint'] as String?)?.trim());
      _loadSenderLatLngFromApi(widget.addressId);
      _initLocationAndRoute();
    });
  }

  // โหลดพิกัดผู้ส่ง
  Future<void> _loadSenderLatLngFromApi(int addressId) async {
    if (_apiBase == null) return;
    final url = Uri.parse("$_apiBase/users/address/$addressId");
    try {
      final res = await http.get(url).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = usersAddressIdGetResFromJson(res.body);
        if (!mounted) return;
        setState(() => senderLatLng = LatLng(data.lat, data.lng));
        if (riderLatLng != null) {
          await _fetchRouteFromOSRM();
          _updateRouteConsumption(riderLatLng!);
        }
      } else {
        debugPrint("โหลดที่อยู่ผู้ส่งไม่สำเร็จ: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("โหลดที่อยู่ผู้ส่งล้มเหลว: $e");
    }
  }

  // เตรียมตำแหน่งไรเดอร์ + stream
  Future<void> _initLocationAndRoute() async {
    final pos = await _getCurrentPosition();
    if (!mounted) return;

    if (pos == null) {
      setState(() => _loading = false);
      return;
    }

    final first = LatLng(pos.latitude, pos.longitude);
    setState(() {
      riderLatLng = first;
      _loading = false;
    });

    if (senderLatLng != null) {
      await _fetchRouteFromOSRM();
      _updateRouteConsumption(first);
    }

    _posSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 1, // ขยับ >= 1m ค่อยอัปเดต
          ),
        ).listen((p) {
          final next = LatLng(p.latitude, p.longitude);
          if (riderLatLng == null) {
            if (!mounted) return;
            setState(() => riderLatLng = next);
            return;
          }
          final moved = _dist(riderLatLng!, next);
          if (moved < 1) return;

          final bearing = _calculateBearing(riderLatLng!, next);
          if (!mounted) return;
          setState(() {
            riderLatLng = next;
            _bearingDeg = bearing;
            _updateRouteConsumption(next);
          });

          final now = DateTime.now();
          if (now.difference(_lastCameraMove).inMilliseconds > 500) {
            _lastCameraMove = now;
            try {
              mapController.move(next, mapController.camera.zoom);
            } catch (_) {}
          }
        }, onError: (e) => debugPrint("position stream error: $e"));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _posSub?.pause();
    } else if (state == AppLifecycleState.resumed) {
      _posSub?.resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _posSub?.cancel();
    super.dispose();
  }

  // เรียก OSRM หาเส้นตามถนนจริง (UI เท่านั้น, ไม่เกี่ยวกับ cache)
  Future<void> _fetchRouteFromOSRM() async {
    if (riderLatLng == null || senderLatLng == null) return;

    final url =
        'https://router.project-osrm.org/route/v1/driving/'
        '${riderLatLng!.longitude},${riderLatLng!.latitude};'
        '${senderLatLng!.longitude},${senderLatLng!.latitude}'
        '?overview=full&geometries=geojson';

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        final List coords = data['routes'][0]['geometry']['coordinates'];
        final pts = coords
            .map(
              (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
            )
            .toList();

        setState(() {
          routePoints = pts;
          traversedPoints = [];
          remainingPoints = List<LatLng>.from(routePoints);
        });
      } else {
        debugPrint("Route API Error: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("Route API Exception: $e");
    }
  }

  // “กินเส้น”
  void _updateRouteConsumption(LatLng current) {
    if (routePoints.isEmpty) return;
    final idx = _nearestRouteIndex(current).clamp(0, routePoints.length);
    traversedPoints = routePoints.sublist(0, idx);
    remainingPoints = routePoints.sublist(idx);
    if (remainingPoints.isNotEmpty) {
      remainingPoints[0] = current; // snap
    } else {
      remainingPoints = [current];
    }
  }

  int _nearestRouteIndex(LatLng p) {
    int bestIdx = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < routePoints.length; i++) {
      final d = _dist(p, routePoints[i]);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return null;
      }
      if (perm == LocationPermission.deniedForever) return null;

      return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint("getCurrentPosition error: $e");
      return null;
    }
  }

  double _calculateBearing(LatLng from, LatLng to) {
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

  // ระยะคงเหลือ (เมตร)
  double _remainingMeters() {
    if (remainingPoints.length < 2) return 0;
    double m = 0;
    for (int i = 0; i < remainingPoints.length - 1; i++) {
      m += _dist(remainingPoints[i], remainingPoints[i + 1]);
    }
    return m;
  }

  String _fmtDistance(double m) => m >= 1000
      ? "${(m / 1000).toStringAsFixed(2)} กม."
      : "${m.toStringAsFixed(0)} ม.";

  // ===========================================================================
  // 1) เปิดกล่องให้ถ่าย/เลือกรูป → บีบอัด → เก็บ base64
  Future<void> _pickImage() async {
    if (riderLatLng == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("ยังไม่เจอตำแหน่งปัจจุบัน")));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x1432BD6C),
                  child: Icon(Icons.photo_camera, color: kGreenDark),
                ),
                title: const Text(
                  "ถ่ายรูปด้วยกล้อง",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final picked = await _picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 80,
                    maxWidth: 1200,
                  );
                  await _handlePickedFile(picked);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x14FF5C8A),
                  child: Icon(Icons.photo_library, color: kPink),
                ),
                title: const Text(
                  "เลือกจากแกลเลอรี",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final picked = await _picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 80,
                    maxWidth: 1200,
                  );
                  await _handlePickedFile(picked);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  /// แปลงภาพ → resize → jpeg(quality 60) → base64 แล้วส่งขึ้นเซิร์ฟเวอร์
  Future<void> _handlePickedFile(XFile? picked) async {
    if (picked == null) return;

    final file = File(picked.path);
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("อ่านไฟล์รูปไม่สำเร็จ")));
      return;
    }
    // resize กว้าง 800 เพื่อให้ไฟล์เล็กลง (พอสำหรับหลักฐาน)
    final resized = img.copyResize(decoded, width: 800);
    final compressed = img.encodeJpg(resized, quality: 60);

    setState(() {
      _imageBase64 = base64Encode(compressed);
    });

    // มีรูปแล้ว → ยิง API อัปเดตสถานะรับงาน
    await _submitAcceptUpdate();
  }

  // ===========================================================================
  // 2) ยิง API: /deliveries/update-status-accept  (แทน /deliveries/arrived)
  Future<void> _submitAcceptUpdate() async {
    if (_apiBase == null || riderLatLng == null || _imageBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ข้อมูลไม่ครบ (ตำแหน่งหรือรูปภาพ)")),
      );
      return;
    }

    setState(() => _sending = true);

    final req = AccepStatusUpdateReq(
      deliveryId: widget.deliveryid,
      riderId: widget.riderId,
      pictureStatus2: _imageBase64!,
      riderLat: riderLatLng!.latitude,
      riderLng: riderLatLng!.longitude,
    );

    final url = Uri.parse("$_apiBase/deliveries/update-status-accept");
    final bodyJson = accepStatusUpdateReqToJson(req);
    debugPrint("POST $url");
    debugPrint("BODY: $bodyJson");

    try {
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json; charset=utf-8"},
        body: bodyJson,
      );

      debugPrint("STATUS: ${res.statusCode}");
      debugPrint("RESP: ${res.body}");

      if (!mounted) return;

      if (res.statusCode == 200) {
        final parsed = accepStatusUpdateResFromJson(res.body);
        debugPrint("✅ update-status-accept OK -> ${parsed.message}");

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("อัปเดตสถานะสำเร็จและอัปโหลดรูปแล้ว ✅"),
            backgroundColor: Colors.green,
          ),
        );

        // ไปหน้า GoReceiveItem (ไม่เปลี่ยนพารามิเตอร์/ระบบเดิม)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GoReceiveItem(
              addressId: widget.addressId,
              riderId: widget.riderId,
              deliveryId: widget.deliveryid,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("อัปเดตไม่สำเร็จ (${res.statusCode})"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint("ERROR update-status-accept: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("เกิดข้อผิดพลาดในการเชื่อมต่อ"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    if (_loading || riderLatLng == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final remainText = _fmtDistance(_remainingMeters());

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          // ===== แผนที่ =====
          FlutterMap(
            mapController: mapController,
            options: MapOptions(initialCenter: riderLatLng!, initialZoom: 17.0),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flutter_application_1',
              ),

              // เส้น “ผ่านแล้ว” เงาเทาโปร่ง
              if (traversedPoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: traversedPoints,
                      strokeWidth: 10,
                      color: Colors.black.withOpacity(0.08),
                    ),
                    Polyline(
                      points: traversedPoints,
                      strokeWidth: 6,
                      color: Colors.black.withOpacity(0.25),
                    ),
                  ],
                ),

              // เส้น “คงเหลือ” ไล่เฉดชมพู > เขียว พร้อมเงา
              if (remainingPoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: remainingPoints,
                      strokeWidth: 12,
                      color: kPink.withOpacity(.18),
                    ),
                    Polyline(
                      points: remainingPoints,
                      strokeWidth: 7,
                      color: kGreen.withOpacity(.90),
                    ),
                  ],
                ),

              // Markers
              MarkerLayer(
                markers: [
                  // Sender (ปลายทางแรก)
                  if (senderLatLng != null)
                    Marker(
                      point: senderLatLng!,
                      width: 64,
                      height: 64,
                      child: Stack(
                        alignment: Alignment.center,
                        children: const [
                          Icon(Icons.location_pin, color: Colors.red, size: 44),
                          Positioned(
                            bottom: 4,
                            child: Text(
                              "ผู้ส่ง",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Rider (หมุนตามทิศทาง + เงา)
                  Marker(
                    point: riderLatLng!,
                    width: 64,
                    height: 64,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 14,
                                spreadRadius: 2,
                                color: Colors.black.withOpacity(.18),
                              ),
                            ],
                          ),
                        ),
                        Transform.rotate(
                          angle: _bearingDeg * (math.pi / 180),
                          child: Image.asset('assets/images/rider_icon.png'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ===== Header กระจกใส + แบรนด์เดลิเวอรี่ =====
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kGreen, kGreenDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 14,
                          color: Colors.black.withOpacity(.15),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Back
                        _glassIcon(
                          icon: Icons.arrow_back,
                          onTap: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 10),

                        // ชื่อ/โลโก้
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.delivery_dining, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                "ไปหาผู้ส่ง • Delivery",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: "Poppins",
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // กล้องเล็งตำแหน่งฉัน
                        _glassIcon(
                          icon: Icons.my_location,
                          onTap: () {
                            if (riderLatLng != null) {
                              mapController.move(
                                riderLatLng!,
                                mapController.camera.zoom,
                              );
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

          // ===== ชิปข้อมูล ขวาบน =====
          Positioned(
            top: MediaQuery.of(context).padding.top + 72,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _infoChip(
                  icon: Icons.straighten,
                  label: "ระยะคงเหลือ",
                  value: remainText,
                ),
                const SizedBox(height: 8),
                _infoChip(
                  icon: Icons.explore,
                  label: "มุ่งหน้า",
                  value: "${_bearingDeg.toStringAsFixed(0)}°",
                ),
              ],
            ),
          ),

          // ===== ปุ่มหลัก “ถึงที่หมาย” =====
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: _primaryButton(
              onTap: _sending ? null : _pickImage,
              label: "ถึงที่หมาย",
              icon: Icons.check_circle_rounded,
              loading: _sending,
            ),
          ),
        ],
      ),
    );
  }

  // ===== Widgets ย่อยสำหรับตกแต่ง (UI เท่านั้น) =====

  Widget _glassIcon({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.20),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.88),
            border: Border.all(color: Colors.white),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(blurRadius: 12, color: Colors.black.withOpacity(.08)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: kGreenDark),
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
                style: const TextStyle(
                  color: kInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required VoidCallback? onTap,
    required String label,
    required IconData icon,
    bool loading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        decoration: BoxDecoration(
          gradient: onTap == null
              ? const LinearGradient(
                  colors: [Color(0xFFB0B0B0), Color(0xFF9A9A9A)],
                )
              : const LinearGradient(
                  colors: [kPink, kGreen],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              blurRadius: 16,
              offset: const Offset(0, 10),
              color: (onTap == null ? Colors.black54 : kGreenDark).withOpacity(
                0.25,
              ),
            ),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
