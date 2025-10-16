import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  LatLng? _selectedPoint;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ===== Header =====
          Container(
            width: double.infinity,
            color: Colors.green, // ✅ ไม่มี radius แล้ว
            padding: const EdgeInsets.only(top: 40, bottom: 20),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 20,
                  child: Image.asset(
                    "assets/images/img_2_cropped.png",
                    width: 40,
                  ),
                ),
                Positioned(
                  right: 20,
                  child: Image.asset(
                    "assets/images/img_2_cropped.png",
                    width: 40,
                  ),
                ),
                Image.asset("assets/images/img_3.png", width: 120),
              ],
            ),
          ),

          // ===== แผนที่ =====
          Expanded(
            child: FlutterMap(
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
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.flutter_application_1',
                ),
                if (_selectedPoint != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedPoint!,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),

      // ปุ่มยืนยัน
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.pinkAccent,
        child: const Icon(Icons.check, color: Colors.white),
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
      ),
    );
  }
}
