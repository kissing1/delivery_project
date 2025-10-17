import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

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

  // เรียก OSRM หาเส้นตามถนนจริง
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
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera, color: Colors.green),
                title: const Text("ถ่ายรูปด้วยกล้อง"),
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
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text("เลือกจากแกลเลอรี"),
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

        // ✅ ไปหน้า GoReceiveItem ทันที (แทนที่หน้านี้ไว้)
        // หมายเหตุ: GoReceiveItem ใช้ชื่อพารามิเตอร์ deliveryId (I ใหญ่)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GoReceiveItem(
              addressId: widget.addressId, // ใช้เป็น fallback ถ้าต้องใช้
              riderId: widget.riderId, // ไรเดอร์ที่กำลังไปส่ง
              deliveryId: widget.deliveryid, // ชื่อ param ต้องเป็น deliveryId
              // riderLocationId: widget.riderId, // (ถ้ามี) ส่งเพิ่มได้
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

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(initialCenter: riderLatLng!, initialZoom: 17.0),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flutter_application_1',
              ),

              if (traversedPoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: traversedPoints,
                      strokeWidth: 6,
                      color: Colors.black.withOpacity(0.25),
                    ),
                  ],
                ),

              if (remainingPoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: remainingPoints,
                      strokeWidth: 6,
                      color: Colors.red,
                    ),
                  ],
                ),

              MarkerLayer(
                markers: [
                  // Rider
                  Marker(
                    point: riderLatLng!,
                    width: 60,
                    height: 60,
                    child: Transform.rotate(
                      angle: _bearingDeg * (math.pi / 180),
                      child: Image.asset('assets/images/rider_icon.png'),
                    ),
                  ),
                  // Sender
                  if (senderLatLng != null)
                    Marker(
                      point: senderLatLng!,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 50,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Header
          SafeArea(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                color: Colors.green,
                child: const Text(
                  "ZapGo",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Poppins",
                  ),
                ),
              ),
            ),
          ),

          // ปุ่ม “ถึงที่หมาย” → เปิดกล่องถ่าย/เลือกภาพ
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sending ? null : _pickImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _sending
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        "ถึงที่หมาย",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
