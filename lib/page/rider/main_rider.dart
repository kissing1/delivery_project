import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/config/config.dart';
import 'package:flutter_application_1/model/responses/ridercar_get_res.dart';
import 'package:flutter_application_1/model/responses/users_id_get_res.dart';
import 'package:flutter_application_1/model/responses/waiting_deliveries_get_res.dart';
import 'package:flutter_application_1/page/login.dart';
import 'package:flutter_application_1/page/rider/delivery/detail_delivery.dart';
import 'package:flutter_application_1/page/rider/Product_Detail.dart';

import 'package:http/http.dart' as http;
import 'package:flutter_application_1/model/responses/history_riders_get_res.dart'
    as his;

/// ======== THEME (Delivery) =========
const Color _kDeliveryGreen = Color(0xFF2ECC71);
const Color _kDeliveryDark = Color(0xFF1B5E20);
const Color _kCardBorder = Color(0x22000000);
const _kEase = Curves.easeOutCubic;

BoxDecoration _pageBg() => const BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFEFFAF2), // ไฮไลต์เขียวอ่อน
      Colors.white, // ลงจอขาว สบายตา
    ],
  ),
);

ShapeBorder _cardShape({double r = 16}) => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(r),
  side: const BorderSide(color: _kCardBorder),
);

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
  String _lastJson = "";
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    Configuration.getConfig()
        .then((cfg) {
          setState(() => _apiBase = (cfg['apiEndpoint'] as String?)?.trim());
          fetchRider(widget.riderid);
          deliverieswaiting();

          // ⏳ รีเฟรชทุก 10 วิ (กันกระพริบด้วย snapshot compare แล้ว)
          _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
            deliverieswaiting();
          });
        })
        .catchError((e) {
          debugPrint("อ่าน config ไม่ได้: $e");
          return null;
        });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
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

      // 🧠 เปรียบเทียบข้อมูลใหม่กับ snapshot เดิม
      final newJson = jsonEncode(data.map((e) => e.toJson()).toList());
      if (newJson == _lastJson) {
        debugPrint("ℹ️ waiting deliveries ไม่มีการเปลี่ยนแปลง");
        return; // ❌ ข้าม setState → ไม่กระพริบ
      }

      debugPrint("✅ waiting deliveries มีการเปลี่ยนแปลง → อัปเดต UI");

      setState(() {
        waitingList = data;
        _lastJson = newJson;
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
      RiderHistoryPage(riderId: widget.riderid),
      RiderVehiclePage(riderId: widget.riderid),
      RiderProfilePage(riderData: _riderData),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _kDeliveryGreen,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.local_shipping_outlined, color: Colors.white),
            SizedBox(width: 8),
            Text(
              "ZapGo",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
            tooltip: 'ออกจากระบบ',
          ),
        ],
      ),
      body: Container(
        decoration: _pageBg(),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: _kEase,
          switchOutCurve: _kEase,
          child: IndexedStack(
            key: ValueKey<int>(_currentIndex),
            index: _currentIndex,
            children: pages,
          ),
        ),
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 8,
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: _kDeliveryGreen,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
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
      ),
    );
  }
}

/// 📝 หน้าที่ 2 — ประวัติการส่ง (ตกแต่ง + animation, ไม่แตะ logic)
class RiderHistoryPage extends StatefulWidget {
  final int riderId;
  const RiderHistoryPage({super.key, required this.riderId});

  @override
  State<RiderHistoryPage> createState() => _RiderHistoryPageState();
}

class _RiderHistoryPageState extends State<RiderHistoryPage> {
  String? _apiBase;
  bool _loading = true;
  String _lastDigest = '';
  List<his.Item> _items = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final cfg = await Configuration.getConfig();
    _apiBase = (cfg['apiEndpoint'] as String?)?.trim();
    await _fetchHistory();
  }

  // ทำ digest เพื่อกันการกระพริบ ถ้าข้อมูลเหมือนเดิมจะไม่ setState
  String _digest(List<his.Item> list) {
    final b = StringBuffer();
    for (final it in list) {
      final d = it.delivery;
      b.writeAll([
        it.id,
        it.status,
        d.nameProduct,
        d.amount,
        d.pictureProduct.hashCode,
      ], '|');
      b.write('||');
    }
    return b.toString();
  }

  Future<void> _fetchHistory() async {
    if (_apiBase == null) return;
    try {
      if (mounted) setState(() => _loading = true);
      final url = Uri.parse("$_apiBase/riders/history/${widget.riderId}");
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final parsed = his.historyRidersGetResFromJson(res.body);
        final newItems = parsed.items;
        final newDigest = _digest(newItems);

        if (newDigest != _lastDigest) {
          if (mounted) {
            setState(() {
              _items = newItems;
              _lastDigest = newDigest;
            });
          }
        } else {
          debugPrint("ℹ️ rider history ไม่มีการเปลี่ยนแปลง");
        }
      } else {
        debugPrint(
          "❌ GET /riders/history/${widget.riderId} -> ${res.statusCode} ${res.body}",
        );
      }
    } catch (e) {
      debugPrint("❌ exception _fetchHistory: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // แปลงรูป (รองรับ base64/URL/ว่าง)
  ImageProvider _imgFrom(String? pic) {
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
      debugPrint('❌ decode history image error: $e');
    }
    return const AssetImage('assets/images/no_image.png');
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'finish':
      case 'done':
        return Colors.green.shade600;
      case 'transporting':
        return Colors.orange.shade700;
      case 'cancel':
      case 'canceled':
        return Colors.red.shade600;
      default:
        return Colors.blueGrey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text(
                "ยังไม่มีประวัติการส่ง",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchHistory,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final it = _items[index];
          final d = it.delivery; // ข้อมูลสินค้าที่ฝังมากับ history
          final img = _imgFrom(d.pictureProduct);
          final statusColor = _statusColor(it.status);

          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 280 + index * 60),
            curve: _kEase,
            builder: (context, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, 14 * (1 - v)),
                child: child,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                // ไปหน้า ProductDetail ส่ง delivery_id และ rider_id
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetail(
                      deliveryId: it.deliveryId,
                      riderId: it.riderId,
                    ),
                  ),
                );
              },
              child: Card(
                elevation: 4,
                shadowColor: _kDeliveryGreen.withOpacity(.2),
                shape: _cardShape(r: 14),
                margin: const EdgeInsets.only(bottom: 14),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // รูปสินค้า + แถบสีสถานะ
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image(
                              image: img,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            bottom: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(.9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                it.status,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // เนื้อหา
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "รายละเอียด",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "ชื่อสินค้า  ",
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 13,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    d.nameProduct,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Text(
                                  "จำนวน  ",
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  "${d.amount}",
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),
                      Icon(Icons.navigate_next, color: Colors.grey.shade600),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
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

    return Container(
      decoration: _pageBg(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: _kEase,
          builder: (context, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - v)),
              child: child,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.directions_car, color: _kDeliveryGreen),
                  SizedBox(width: 8),
                  Text(
                    "ยานพาหนะ",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 5,
                shadowColor: _kDeliveryGreen.withOpacity(.25),
                shape: _cardShape(),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 110,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
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
                                fontWeight: FontWeight.w700,
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
        ),
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

    return Container(
      decoration: _pageBg(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: _kEase,
          builder: (context, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - v)),
              child: child,
            ),
          ),
          child: Column(
            children: [
              CircleAvatar(radius: 50, backgroundImage: getProfileImage()),
              const SizedBox(height: 16),
              Text(
                riderData!["name"] ?? "-",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _kDeliveryDark,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 4,
                shadowColor: _kDeliveryGreen.withOpacity(.2),
                shape: _cardShape(),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _profileRow("ชื่อ", riderData!["name"] ?? "-"),
                      const SizedBox(height: 10),
                      _profileRow("เบอร์โทร", riderData!["phone"] ?? "-"),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileRow(String k, String v) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            "$k:",
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// 🚚 หน้าที่ 1 — ที่ต้องไปส่ง (ตกแต่ง + animation, ไม่แตะ logic)
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

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 280 + index * 60),
          curve: _kEase,
          builder: (context, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, 14 * (1 - v)),
              child: child,
            ),
          ),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetailDelivery(
                    deliveryId: d.deliveryId,
                    riderId: riderId,
                  ),
                ),
              );
            },
            child: Card(
              elevation: 5,
              shadowColor: _kDeliveryGreen.withOpacity(.25),
              shape: _cardShape(r: 14),
              margin: const EdgeInsets.only(bottom: 14),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // รูปสินค้า
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image(
                        image: getProductImage(d.pictureProduct),
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // เนื้อหา
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "รายละเอียด",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "ชื่อสินค้า  ",
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  d.nameProduct ?? '-',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Text(
                                "ผู้รับ  ",
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  receiverName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: Colors.grey.shade600),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
