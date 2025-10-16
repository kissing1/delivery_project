import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/page/rider/delivery/rider_gosender.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart'; // ✅ เพิ่มสำหรับหาพิกัด
import 'package:flutter_application_1/config/config.dart';
import 'package:flutter_application_1/model/responses/users_address_id_get_res.dart';

class SenderAddress extends StatefulWidget {
  final int addressId;
  final int riderId;
  final int deliveryid;

  const SenderAddress({
    super.key,
    required this.addressId,
    required this.riderId,
    required this.deliveryid,
  });

  @override
  State<SenderAddress> createState() => _SenderAddressState();
}

class _SenderAddressState extends State<SenderAddress> {
  String? _apiBase;
  UsersAddressIdGetRes? getsenderlatlng;
  final MapController mapController = MapController();

  LatLng? senderLatLng;
  LatLng? riderLatLng; // ✅ พิกัดของ Rider
  bool _loading = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Configuration.getConfig().then((cfg) {
      setState(() => _apiBase = (cfg['apiEndpoint'] as String?)?.trim());
      getaddresssender();
      getRiderLocation(); // ✅ ดึงตำแหน่ง rider ตอนเปิดหน้า
    });
  }

  /// 📡 ดึงพิกัดผู้ส่งจาก API
  Future<void> getaddresssender() async {
    if (_apiBase == null) return;
    final url = Uri.parse("$_apiBase/users/address/${widget.addressId}");
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final data = usersAddressIdGetResFromJson(res.body);
      setState(() {
        getsenderlatlng = data;
        senderLatLng = LatLng(data.lat, data.lng);
        _loading = false;
      });
    } else {
      debugPrint("โหลดข้อมูลที่อยู่ผู้ส่งไม่สำเร็จ: ${res.statusCode}");
    }
  }

  /// 📍 ดึงตำแหน่งปัจจุบันของ Rider
  Future<void> getRiderLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint("⚠️ Location service not enabled");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint("❌ Location permission denied");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint("❌ Location permission denied forever");
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      riderLatLng = LatLng(position.latitude, position.longitude);
    });

    debugPrint(
      "📍 Rider Lat: ${position.latitude}, Lng: ${position.longitude}",
    );
  }

  /// ✅ ยิง API ยืนยันรับงาน + ตำแหน่ง rider
  Future<void> deliveryaccept() async {
    if (_apiBase == null || riderLatLng == null) return;
    setState(() => _isLoading = true);

    final body = {
      "delivery_id": widget.deliveryid,
      "rider_id": widget.riderId,
      "rider_lat": riderLatLng!.latitude,
      "rider_lng": riderLatLng!.longitude,
    };
    final url = Uri.parse("$_apiBase/deliveries/accept");

    debugPrint("📦 POST $url");
    debugPrint("📤 BODY: $body");

    try {
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json; charset=utf-8"},
        body: jsonEncode(body),
      );

      debugPrint("📥 STATUS: ${res.statusCode}");
      debugPrint("📥 RESPONSE: ${res.body}");

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ ยืนยันการรับงานสำเร็จ"),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("❌ ยืนยันไม่สำเร็จ (${res.statusCode})"),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("❌ ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("เกิดข้อผิดพลาดในการเชื่อมต่อ"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.green.shade600,
        title: const Text(
          "📦 รับสินค้าจากผู้ส่ง",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading || senderLatLng == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 🧭 Header
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.green),
                          const SizedBox(width: 6),
                          Text(
                            "พิกัดผู้ส่ง",
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Lat: ${getsenderlatlng!.lat} | Lng: ${getsenderlatlng!.lng}",
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "โปรดเดินทางไปยังจุดนี้เพื่อรับสินค้า",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                // 🗺️ Map
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: FlutterMap(
                        mapController: mapController,
                        options: MapOptions(
                          initialCenter: senderLatLng!,
                          initialZoom: 15.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName:
                                'com.example.flutter_application_1',
                            maxNativeZoom: 19,
                          ),
                          MarkerLayer(
                            markers: [
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
                              if (riderLatLng != null)
                                Marker(
                                  point: riderLatLng!,
                                  width: 60,
                                  height: 60,
                                  child: Image.asset(
                                    'assets/images/rider_icon.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ✅ ปุ่มยืนยัน
                // ✅ ปุ่มยืนยัน
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              await deliveryaccept(); // ✅ เรียกยิง API ก่อน
                              if (mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RiderGosender(
                                      addressId: widget.addressId,
                                      riderId: widget.riderId,
                                      deliveryid: widget.deliveryid,
                                    ),
                                  ),
                                );
                              }
                            },

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              "ยืนยันการรับสินค้า",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
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
