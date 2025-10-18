// lib/page/rider/delivery/go_receive_item.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/config/config.dart';

// ✅ ใช้หน้าเดิมตามโปรเจกต์
import 'package:flutter_application_1/page/rider/main_rider.dart';

// Models
import 'package:flutter_application_1/model/responses/overview_riders_get_res.dart';
import 'package:flutter_application_1/model/requsts/location_update_rider_post_req.dart';
import 'package:flutter_application_1/model/responses/users_address_id_get_res.dart';

// Map & Location
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

// HTTP
import 'package:http/http.dart' as http;

// รูปภาพ
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

// ===================== THEME (Delivery Luxury) =====================
const _kBg = Color(0xFFF6FAF8);
const _kGreen = Color(0xFF32BD6C);
const _kGreenDark = Color(0xFF249B58);
const _kPink = Color(0xFFFF5C8A);
const _kInk = Color(0xFF111418);

class GoReceiveItem extends StatefulWidget {
  final int addressId;
  final int riderId;
  final int deliveryId;
  final int? riderLocationId;

  const GoReceiveItem({
    super.key,
    required this.addressId,
    required this.riderId,
    required this.deliveryId,
    this.riderLocationId,
  });

  @override
  State<GoReceiveItem> createState() => _GoReceiveItemState();
}

class _GoReceiveItemState extends State<GoReceiveItem>
    with WidgetsBindingObserver {
  final MapController _map = MapController();
  StreamSubscription<Position>? _posSub;

  String? _apiBase;

  // พิกัดหลัก
  LatLng? _rider;
  LatLng? _receiver;

  // เส้นทางรวม + กินเส้น
  final _dist = const Distance();
  List<LatLng> _route = [];
  List<LatLng> _traversed = [];
  List<LatLng> _remaining = [];

  // หมุน marker + คุมกล้อง
  double _bearingDeg = 0;
  DateTime _lastCameraMove = DateTime.fromMillisecondsSinceEpoch(0);

  // throttle POST อัปเดตตำแหน่ง (อย่างน้อยทุก 2 วิ)
  DateTime _lastPost = DateTime.fromMillisecondsSinceEpoch(0);

  bool _loading = true;
  bool _sending = false;

  // image picker
  final ImagePicker _picker = ImagePicker();

  // ค่า non-null สำหรับ riderLocationId (fallback -> riderId)
  int get _ridLocId => widget.riderLocationId ?? widget.riderId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    Configuration.getConfig().then((cfg) async {
      if (!mounted) return;
      _apiBase = (cfg['apiEndpoint'] as String?)?.trim();

      // โหลด overview เริ่มต้น
      await _loadOverview();

      // เริ่มติดตามตำแหน่งจริง
      await _initPositionStream();

      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _posSub?.cancel();
    super.dispose();
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

  // ---------------------------------------------------------------------------
  // APIs (ไม่แก้ logic)

  Future<void> _loadOverview() async {
    if (_apiBase == null) return;
    try {
      final url = Uri.parse("$_apiBase/riders/overview/${widget.riderId}");
      final res = await http.get(url).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final ov = overviewRidersGetResFromJson(res.body);
        _rider = LatLng(ov.riderLat, ov.riderLng);
        _receiver = LatLng(ov.receiverLat, ov.receiverLng);

        await _fetchRouteFromOSRM();
        _updateRouteConsumption(_rider!);
        setState(() {});
      } else {
        await _loadReceiverFromAddress(widget.addressId);
      }
    } catch (_) {
      await _loadReceiverFromAddress(widget.addressId);
    }
  }

  Future<void> _loadReceiverFromAddress(int addressId) async {
    if (_apiBase == null) return;
    try {
      final res = await http.get(
        Uri.parse("$_apiBase/users/address/$addressId"),
      );
      if (res.statusCode == 200) {
        final data = usersAddressIdGetResFromJson(res.body);
        _receiver = LatLng(data.lat, data.lng);

        if (_rider != null) {
          await _fetchRouteFromOSRM();
          _updateRouteConsumption(_rider!);
        }
        setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _postLocationUpdate(LatLng p) async {
    if (_apiBase == null) return;

    final now = DateTime.now();
    if (now.difference(_lastPost).inMilliseconds < 2000) return;
    _lastPost = now;

    final body = LocationUpdateRiderPostReq(
      riderId: widget.riderId,
      lat: p.latitude,
      lng: p.longitude,
      riderLocationId: _ridLocId,
    );

    try {
      await http.post(
        Uri.parse("$_apiBase/rider/location/update"),
        headers: const {"Content-Type": "application/json; charset=utf-8"},
        body: locationUpdateRiderPostReqToJson(body),
      );
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Route (OSRM) (ไม่แก้ logic)

  Future<void> _fetchRouteFromOSRM() async {
    if (_rider == null || _receiver == null) return;

    final url =
        'https://router.project-osrm.org/route/v1/driving/'
        '${_rider!.longitude},${_rider!.latitude};'
        '${_receiver!.longitude},${_receiver!.latitude}'
        '?overview=full&geometries=geojson';

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List coords = data['routes'][0]['geometry']['coordinates'];
        final pts = coords
            .map(
              (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
            )
            .toList();

        _route = pts;
        _traversed = [];
        _remaining = List<LatLng>.from(_route);
        setState(() {});
      }
    } catch (_) {}
  }

  void _updateRouteConsumption(LatLng current) {
    if (_route.isEmpty) return;
    final idx = _nearestRouteIndex(current).clamp(0, _route.length);
    _traversed = _route.sublist(0, idx);
    _remaining = _route.sublist(idx);
    if (_remaining.isNotEmpty) {
      _remaining[0] = current;
    } else {
      _remaining = [current];
    }
    setState(() {});
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

  // ---------------------------------------------------------------------------
  // Location stream (ไม่แก้ logic)

  Future<void> _initPositionStream() async {
    final pos = await _getCurrentPosition();
    if (!mounted) return;

    if (pos != null) {
      final first = LatLng(pos.latitude, pos.longitude);
      _rider ??= first;
      if (_receiver != null && _route.isEmpty) {
        await _fetchRouteFromOSRM();
      }
      _updateRouteConsumption(_rider!);
      setState(() {});
    }

    _posSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 1,
          ),
        ).listen(
          (p) {
            final next = LatLng(p.latitude, p.longitude);
            if (_rider == null) {
              setState(() => _rider = next);
              return;
            }

            final moved = _dist(_rider!, next);
            if (moved < 1) return;

            final bearing = _bearing(_rider!, next);

            _rider = next;
            _bearingDeg = bearing;
            _updateRouteConsumption(next);

            final now = DateTime.now();
            if (now.difference(_lastCameraMove).inMilliseconds > 500) {
              _lastCameraMove = now;
              try {
                _map.move(next, _map.camera.zoom);
              } catch (_) {}
            }

            _postLocationUpdate(next);
          },
          onError: (e) {
            if (kDebugMode) debugPrint("position stream error: $e");
          },
        );
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
    } catch (_) {
      return null;
    }
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

  // ---------------------------------------------------------------------------
  // Finish flow (ไม่แก้ logic)

  Future<void> _pickImage() async {
    if (_rider == null) {
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
                  child: Icon(Icons.photo_camera, color: _kGreenDark),
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
                  child: Icon(Icons.photo_library, color: _kPink),
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

  Future<void> _handlePickedFile(XFile? picked) async {
    if (picked == null) return;

    setState(() => _sending = true);
    try {
      final bytes = await picked.readAsBytes();

      // บีบอัด/resize เล็กลงเพื่อส่งเร็วขึ้น
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("อ่านไฟล์รูปไม่สำเร็จ")));
        return;
      }
      final resized = img.copyResize(decoded, width: 1000);
      final jpg = img.encodeJpg(resized, quality: 70);
      final base64Image = base64Encode(jpg);

      await _submitFinish(base64Image);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("เกิดข้อผิดพลาดกับรูปภาพ: $e")));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _submitFinish(String base64Image) async {
    if (_apiBase == null) return;

    final url = Uri.parse("$_apiBase/deliveries/update-status-finish");
    final body = {
      "delivery_id": widget.deliveryId,
      "picture_status3": base64Image,
      "rider_id": widget.riderId,
    };

    try {
      final res = await http.post(
        url,
        headers: const {"Content-Type": "application/json; charset=utf-8"},
        body: jsonEncode(body),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        // ✅ แจ้งความสำเร็จแบบหรูหราโทนเดลิเวอรี่ แล้วค่อยเปลี่ยนหน้า
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: _kGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  "ส่งของเสร็จสิ้น ✅",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );

        // หน่วงสั้น ๆ ให้ผู้ใช้เห็นข้อความ แล้วค่อยกลับหน้า MainRider
        await Future.delayed(const Duration(milliseconds: 1200));
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => MainRider(riderid: widget.riderId)),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Text("อัปเดตไม่สำเร็จ (${res.statusCode})"),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text("เชื่อมต่อไม่สำเร็จ: $e"),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers (UI-only)

  double _remainingMeters() {
    if (_remaining.length < 2) return 0;
    double m = 0;
    for (int i = 0; i < _remaining.length - 1; i++) {
      m += _dist(_remaining[i], _remaining[i + 1]);
    }
    return m;
  }

  String _fmtDistance(double m) => m >= 1000
      ? "${(m / 1000).toStringAsFixed(2)} กม."
      : "${m.toStringAsFixed(0)} ม.";

  // ---------------------------------------------------------------------------
  // UI

  @override
  Widget build(BuildContext context) {
    if (_loading || _rider == null || _receiver == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final remainText = _fmtDistance(_remainingMeters());

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // ===== Map =====
          FlutterMap(
            mapController: _map,
            options: MapOptions(initialCenter: _rider!, initialZoom: 17),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flutter_application_1',
              ),

              // ผ่านแล้ว (เทาโปร่ง + เงา)
              if (_traversed.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _traversed,
                      strokeWidth: 10,
                      color: Colors.black.withOpacity(0.08),
                    ),
                    Polyline(
                      points: _traversed,
                      strokeWidth: 6,
                      color: Colors.black.withOpacity(0.25),
                    ),
                  ],
                ),

              // คงเหลือ (ชมพูเรือง + เขียวเด่น)
              if (_remaining.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _remaining,
                      strokeWidth: 12,
                      color: _kPink.withOpacity(.18),
                    ),
                    Polyline(
                      points: _remaining,
                      strokeWidth: 7,
                      color: _kGreen.withOpacity(.90),
                    ),
                  ],
                ),

              // Markers
              MarkerLayer(
                markers: [
                  // Receiver
                  Marker(
                    point: _receiver!,
                    width: 64,
                    height: 64,
                    child: Stack(
                      alignment: Alignment.center,
                      children: const [
                        Icon(Icons.location_pin, color: Colors.red, size: 44),
                        Positioned(
                          bottom: 4,
                          child: Text(
                            "ผู้รับ",
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
                  // Rider
                  Marker(
                    point: _rider!,
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

          // ===== Header (Gradient + Glass) =====
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kGreen, _kGreenDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 14,
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
                    _glassIcon(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.delivery_dining, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            "ไปหาผู้รับ • Delivery",
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: "Poppins",
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _glassIcon(
                      icon: Icons.my_location,
                      onTap: () {
                        if (_rider != null) {
                          _map.move(_rider!, _map.camera.zoom);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ===== Info chips (ขวาบน) =====
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

          // ===== ปุ่มหลัก =====
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: _primaryButton(
              onTap: _sending ? null : _pickImage,
              label: "ถึงที่อยู่ของผู้รับ",
              icon: Icons.check_circle_rounded,
              loading: _sending,
            ),
          ),
        ],
      ),
    );
  }

  // ========================= UI Pieces =========================

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.90),
        border: Border.all(color: Colors.white),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(blurRadius: 12, color: Colors.black.withOpacity(.08)),
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
                  colors: [_kPink, _kGreen],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              blurRadius: 16,
              offset: const Offset(0, 10),
              color: (onTap == null ? Colors.black54 : _kGreenDark).withOpacity(
                .25,
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
