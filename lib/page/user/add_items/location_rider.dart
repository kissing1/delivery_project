import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
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

class _LocationRiderState extends State<LocationRider> {
  final MapController _map = MapController();
  StreamSubscription<DocumentSnapshot>? _riderStream;

  LatLng? _rider;
  LatLng? _receiver;
  double _bearingDeg = 0;

  List<LatLng> _route = [];
  List<LatLng> _remaining = [];
  final _dist = const Distance();

  bool _mapReady = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchInitialPosition();
  }

  @override
  void dispose() {
    _riderStream?.cancel();
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

        // ✅ เช็คว่า delivery_id เป็น null ไหม
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
        _initFirestoreListener();
      } else {
        debugPrint("❌ overview error: ${res.statusCode} ${res.body}");
      }
    } catch (e) {
      debugPrint("❌ overview exception: $e");
    } finally {
      setState(() => _loading = false);
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
          if (mounted) {
            _map.move(next, _map.camera.zoom);
          }
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
      setState(() {});
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

  /// ✅ Popup แสดงว่า "ขนส่งเสร็จสิ้น"
  void _showDeliveryCompletePopup() {
    if (!mounted) return;
    final snackBar = SnackBar(
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.green,
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_rider == null || _receiver == null) {
      return const Scaffold(body: Center(child: Text("ไม่พบตำแหน่ง")));
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _rider!,
              initialZoom: 17,
              onMapReady: () {
                setState(() => _mapReady = true);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flutter_application_1',
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
                      child: Image.asset(
                        'assets/images/rider_icon.png',
                        width: 60,
                      ),
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
          SafeArea(
            child: Container(
              color: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Row(
                    children: const [
                      Icon(Icons.location_on, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        "ตำแหน่งของผู้รับ",
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: const [
                      Icon(Icons.delivery_dining, color: Colors.white),
                      SizedBox(width: 6),
                      Text("ไรเดอร์", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
