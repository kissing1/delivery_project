import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/config/config.dart';
import 'package:flutter_application_1/model/responses/ridercar_get_res.dart';
import 'package:flutter_application_1/model/responses/users_id_get_res.dart';
import 'package:flutter_application_1/model/responses/waiting_deliveries_get_res.dart';
import 'package:flutter_application_1/page/login.dart';
import 'package:flutter_application_1/page/rider/delivery/detail_delivery.dart';
import 'package:http/http.dart' as http;

class MainRider extends StatefulWidget {
  final int riderid;
  const MainRider({super.key, required this.riderid});

  @override
  State<MainRider> createState() => _MainRiderState();
}

class _MainRiderState extends State<MainRider> {
  int _currentIndex = 0;
  String? _apiBase;
  Map<String, dynamic>? _riderData;
  List<WaitingDeliveriesGetRes> waitingList = [];
  Map<int, String> receiverNames = {};

  @override
  void initState() {
    super.initState();
    Configuration.getConfig()
        .then((cfg) {
          setState(() => _apiBase = (cfg['apiEndpoint'] as String?)?.trim());
          fetchRider(widget.riderid);
          deliverieswaiting();
        })
        .catchError((e) {
          debugPrint("อ่าน config ไม่ได้: $e");
          return null;
        });
  }

  Future<void> fetchRider(int userid) async {
    if (_apiBase == null) return;
    final url = Uri.parse("$_apiBase/users/$userid");
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _riderData = data;
      });
    } else {
      debugPrint("โหลดข้อมูล rider ไม่สำเร็จ: ${res.statusCode}");
    }
  }

  Future<void> deliverieswaiting() async {
    if (_apiBase == null) return;
    final url = Uri.parse("$_apiBase/deliveries/waiting");
    final res = await http.get(url);
    if (res.statusCode == 200) {
      final data = waitingDeliveriesGetResFromJson(res.body);
      setState(() {
        waitingList = data;
      });
      for (var d in data) {
        fetchReceiverName(d.userIdReceiver);
      }
    } else {
      debugPrint("โหลดข้อมูลรายการรอส่งไม่สำเร็จ: ${res.statusCode}");
    }
  }

  Future<void> fetchReceiverName(int userId) async {
    if (_apiBase == null) return;
    if (receiverNames.containsKey(userId)) return;

    final url = Uri.parse("$_apiBase/users/$userId");
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final data = usersIdGetResFromJson(res.body);
      setState(() {
        receiverNames[userId] = data.name;
      });
    } else {
      debugPrint("โหลดชื่อผู้รับไม่สำเร็จ: ${res.statusCode}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      RiderDeliveryPage(
        deliveries: waitingList,
        receiverNames: receiverNames,
        riderId: widget.riderid,
      ),
      const RiderHistoryPage(),
      RiderVehiclePage(riderId: widget.riderid),
      RiderProfilePage(riderData: _riderData),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2ecc71),
        title: const Text(
          "ZapGo",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF2ecc71),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping),
            label: "ที่ต้องไปส่ง",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: "ประวัติการส่ง",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: "ยานพาหนะ",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "โปรไฟล์"),
        ],
      ),
    );
  }
}

/// 📝 หน้าที่ 2
class RiderHistoryPage extends StatelessWidget {
  const RiderHistoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "📜 ประวัติการส่ง",
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// 🚗 หน้าที่ 3
class RiderVehiclePage extends StatefulWidget {
  final int riderId; // ✅ เพิ่มรับค่า riderId จาก MainRider

  const RiderVehiclePage({super.key, required this.riderId});

  @override
  State<RiderVehiclePage> createState() => _RiderVehiclePageState();
}

class _RiderVehiclePageState extends State<RiderVehiclePage> {
  RidercarGetRes? _riderCar;
  String? _apiBase;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConfigAndData();
  }

  Future<void> _loadConfigAndData() async {
    final cfg = await Configuration.getConfig();
    _apiBase = (cfg['apiEndpoint'] as String?)?.trim();
    if (_apiBase != null) {
      await fetchRiderCar(widget.riderId); // ✅ ดึงจากค่า riderId ที่ส่งมา
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> fetchRiderCar(int riderId) async {
    final url = Uri.parse("$_apiBase/users/$riderId/rider-car");
    final res = await http.get(url);

    if (res.statusCode == 200) {
      setState(() {
        _riderCar = ridercarGetResFromJson(res.body);
      });
    } else {
      debugPrint("โหลดข้อมูลรถไม่สำเร็จ: ${res.statusCode}");
    }
  }

  ImageProvider getProductImage(String? pic) {
    if (pic == null || pic.isEmpty) {
      return const AssetImage('assets/images/no_image.png');
    }
    try {
      final cleaned = pic
          .replaceAll(RegExp(r'^data:image/[^;]+;base64,'), '')
          .replaceAll(RegExp(r'\s+'), '');
      if (cleaned.length > 100 && !pic.startsWith('http')) {
        return MemoryImage(base64Decode(cleaned));
      }
      if (pic.startsWith('http')) return NetworkImage(pic);
    } catch (e) {
      debugPrint('❌ Decode product image error: $e');
    }
    return const AssetImage('assets/images/no_image.png');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_riderCar == null) {
      return const Center(child: Text("ไม่พบข้อมูลยานพาหนะ"));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "ยานพาหนะ",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.black12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 110,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: getProductImage(_riderCar!.imageCar),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ประเภท: ${_riderCar!.carType}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "ป้ายทะเบียน: ${_riderCar!.plateNumber}",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 👤 หน้าที่ 4
class RiderProfilePage extends StatelessWidget {
  final Map<String, dynamic>? riderData;
  const RiderProfilePage({super.key, this.riderData});

  ImageProvider getProfileImage() {
    final pic = riderData?["picture"];
    if (pic == null || pic.toString().isEmpty) {
      return const AssetImage("assets/images/profile_rider.png");
    }
    try {
      if (pic.toString().length > 100 && !pic.toString().startsWith("http")) {
        final cleaned = pic.toString().replaceAll(
          RegExp(r'^data:image/[^;]+;base64,'),
          "",
        );
        final bytes = base64Decode(cleaned);
        return MemoryImage(bytes);
      }
      if (pic.toString().startsWith("http")) {
        return NetworkImage(pic.toString());
      }
    } catch (_) {}
    return const AssetImage("assets/images/profile_rider.png");
  }

  @override
  Widget build(BuildContext context) {
    if (riderData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          CircleAvatar(radius: 50, backgroundImage: getProfileImage()),
          const SizedBox(height: 20),
          const Text(
            "โปรไฟล์ไรเดอร์",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextFormField(
            initialValue: riderData!["name"] ?? "",
            readOnly: true,
            decoration: const InputDecoration(
              labelText: "ชื่อ",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: riderData!["phone"] ?? "",
            readOnly: true,
            decoration: const InputDecoration(
              labelText: "เบอร์โทร",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: riderData!["car_type"] ?? "",
            readOnly: true,
            decoration: const InputDecoration(
              labelText: "ยานพาหนะ",
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

/// 🚚 หน้าที่ 1 — หน้าที่คุณให้มา
class RiderDeliveryPage extends StatelessWidget {
  final List<WaitingDeliveriesGetRes> deliveries;
  final Map<int, String> receiverNames;
  final int riderId;

  const RiderDeliveryPage({
    super.key,
    required this.deliveries,
    required this.receiverNames,
    required this.riderId,
  });

  ImageProvider getProductImage(String? pic) {
    if (pic == null || pic.isEmpty) {
      return const AssetImage('assets/images/no_image.png');
    }
    try {
      final cleaned = pic
          .replaceAll(RegExp(r'^data:image/[^;]+;base64,'), '')
          .replaceAll(RegExp(r'\s+'), '');
      if (cleaned.length > 100 && !pic.startsWith('http')) {
        return MemoryImage(base64Decode(cleaned));
      }
      if (pic.startsWith('http')) return NetworkImage(pic);
    } catch (e) {
      debugPrint('❌ Decode product image error: $e');
    }
    return const AssetImage('assets/images/no_image.png');
  }

  @override
  Widget build(BuildContext context) {
    if (deliveries.isEmpty) {
      return const Center(
        child: Text("ยังไม่มีงานจัดส่ง", style: TextStyle(fontSize: 20)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: deliveries.length,
      itemBuilder: (context, index) {
        final d = deliveries[index];
        final receiverName = receiverNames[d.userIdReceiver] ?? 'กำลังโหลด...';

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DetailDelivery(deliveryId: d.deliveryId, riderId: riderId),
              ),
            );
          },
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Colors.black12),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: getProductImage(d.pictureProduct),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "รายละเอียด",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text("ชื่อสินค้า: ${d.nameProduct ?? '-'}"),
                        Text("ผู้รับ: $receiverName"),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
