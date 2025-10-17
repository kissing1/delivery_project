// lib/page/rider/delivery/go_receive_item.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/config/config.dart';

// ✅ เพิ่ม import เพื่อนำทางกลับหน้า MainRider
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

// ✅ สำหรับเลือกรูป/ถ่ายรูป + บีบอัด
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

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
  // APIs

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
  // Route (OSRM)

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
  // Location stream

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
  // Finish flow: ถ่าย/เลือกภาพ → บีบอัด → ส่ง finish → กลับ MainRider

  Future<void> _pickImage() async {
    if (_rider == null) {
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
      "picture_status3":
          base64Image, // ← ถ้า API ต้องการ URL ให้เปลี่ยนเป็น URL
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
        // กลับหน้า MainRider และล้างสแต็กหน้าก่อนหน้า
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => MainRider(riderid: widget.riderId)),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("อัปเดตไม่สำเร็จ (${res.statusCode})")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("เชื่อมต่อไม่สำเร็จ: $e")));
    }
  }

  // ---------------------------------------------------------------------------
  // UI

  @override
  Widget build(BuildContext context) {
    if (_loading || _rider == null || _receiver == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(initialCenter: _rider!, initialZoom: 17),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flutter_application_1',
              ),
              if (_traversed.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _traversed,
                      strokeWidth: 6,
                      color: Colors.black.withOpacity(0.25),
                    ),
                  ],
                ),
              if (_remaining.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _remaining,
                      strokeWidth: 6,
                      color: Colors.red,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _rider!,
                    width: 60,
                    height: 60,
                    child: Transform.rotate(
                      angle: _bearingDeg * (math.pi / 180),
                      child: Image.asset('assets/images/rider_icon.png'),
                    ),
                  ),
                  Marker(
                    point: _receiver!,
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

          // ปุ่ม ถึงที่อยู่ของผู้รับ → เปิดกล่องถ่าย/เลือกรูป
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
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        "ถึงที่อยู่ของผู้รับ",
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
