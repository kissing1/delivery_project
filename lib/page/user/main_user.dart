import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/config/config.dart';
import 'package:flutter_application_1/model/requsts/address_list_post_req.dart';
import 'package:flutter_application_1/model/requsts/delete_addresses_post_req.dart';
import 'package:flutter_application_1/model/responses/delete_addresses_get_res.dart';
import 'package:flutter_application_1/model/responses/receiver_by_get_res.dart';
import 'package:flutter_application_1/page/login.dart';
import 'package:flutter_application_1/page/user/AddAnAddressPage.dart';
import 'package:flutter_application_1/page/user/add_items/Delivery_status.dart';
import 'package:flutter_application_1/page/user/add_items/add_Delivery_work.dart';
import 'package:flutter_application_1/page/user/detail_product.dart';
import 'package:flutter_application_1/page/user/user_%20record.dart';
import 'package:flutter_application_1/widgets/bottom_nav.dart';
import 'package:http/http.dart' as http;

/// ✅ ธีมหลัก
const Color kGreen = Color(0xFF2ECC71);

class MainUser extends StatefulWidget {
  final int userid;
  const MainUser({super.key, required this.userid});

  @override
  State<MainUser> createState() => _MainUserState();
}

class _MainUserState extends State<MainUser>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 1;
  String? _apiBase;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _addressList;
  Timer? _waitCheckTimer;

  @override
  void initState() {
    super.initState();
    Configuration.getConfig().then((cfg) {
      setState(() => _apiBase = (cfg['apiEndpoint'] as String?)?.trim());
      FetchUser(widget.userid);
      FetchAddresses(widget.userid);
      _fetchWaitReceive(); // โหลดครั้งแรก
      _startAutoCheck(); // ✅ เริ่มจับเวลาเช็คข้อมูล
    });
  }

  @override
  void dispose() {
    _waitCheckTimer?.cancel(); // ✅ ยกเลิก Timer ตอนออก
    super.dispose();
  }

  void _startAutoCheck() {
    _waitCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _checkForUpdates();
    });
  }

  /// ✅ ฟังก์ชันนี้จะไม่ setState ถ้าข้อมูลไม่เปลี่ยน
  Future<void> _checkForUpdates() async {
    if (_apiBase == null) return;
    try {
      final url = Uri.parse(
        "$_apiBase/deliveries/by-receiver/${widget.userid}",
      );
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final parsed = byReceiverGetResFromJson(res.body);
        // 🧠 เทียบข้อมูลเก่ากับใหม่
        if (!_listEquals(parsed.items, _waitReceiveItems)) {
          setState(() {
            _waitReceiveItems = parsed.items;
          });
        }
      }
    } catch (e) {
      debugPrint("❌ update check error: $e");
    }
  }

  /// ✅ เช็คว่า list เปลี่ยนจริงไหม (compare id หรือจำนวนสินค้า)
  bool _listEquals(List<Item> a, List<Item> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].amount != b[i].amount) {
        return false;
      }
    }
    return true;
  }

  // ignore: unused_element
  List<Item> _waitReceiveItems = [];
  bool _waitLoading = false;

  Future<void> _fetchWaitReceive() async {
    if (_apiBase == null) return;
    setState(() => _waitLoading = true);
    try {
      final url = Uri.parse(
        "$_apiBase/deliveries/by-receiver/${widget.userid}",
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final parsed = byReceiverGetResFromJson(res.body);
        setState(() {
          _waitReceiveItems = parsed.items;
        });
      }
    } catch (e) {
      debugPrint("❌ fetch error: $e");
    } finally {
      setState(() => _waitLoading = false);
    }
  }

  Future<void> FetchUser(int userid) async {
    if (_apiBase == null) return;
    final res = await http.get(Uri.parse("$_apiBase/users/$userid"));
    if (res.statusCode == 200) {
      setState(() => _userData = jsonDecode(res.body));
    }
  }

  Future<void> FetchAddresses(int userid) async {
    if (_apiBase == null) return;
    final reqBody = AddressListPostReq(userId: userid, limit: 10);
    final res = await http.post(
      Uri.parse("$_apiBase/users/addresses/list"),
      headers: {"Content-Type": "application/json; charset=utf-8"},
      body: addressListPostReqToJson(reqBody),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data is Map<String, dynamic>) {
        setState(() => _addressList = data);
      }
    }
  }

  ImageProvider getProfileImage() {
    final pic = _userData?["picture"];
    if (pic == null || pic.toString().isEmpty) {
      return const AssetImage("assets/images/profile.png");
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
    return const AssetImage("assets/images/profile.png");
  }

  Future<void> _deleteAddress(dynamic addressId) async {
    if (_apiBase == null || addressId == null) return;
    try {
      final reqBody = DeleteAddressesPostReq(
        userId: widget.userid,
        addressId: addressId.toString(),
      );
      final res = await http.post(
        Uri.parse("$_apiBase/users/addresses/delete"),
        headers: {"Content-Type": "application/json; charset=utf-8"},
        body: deleteAddressesPostReqToJson(reqBody),
      );

      if (res.statusCode == 200) {
        final data = deleteAddressesGetResFromJson(res.body);
        if (data.ok == true) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("ลบที่อยู่สำเร็จ ✅")));
          await FetchAddresses(widget.userid);
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(data.message)));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("เกิดข้อผิดพลาด: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      body: _buildBody(w),
      bottomNavigationBar: MyBottomNav(
        currentIndex: _currentIndex > 2 ? 2 : _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        activeColor: kGreen,
      ),
    );
  }

  Widget _buildBody(double w) {
    switch (_currentIndex) {
      case 0:
        return _buildReceivePage();
      case 1:
        return _buildHomePage(w);
      case 2:
        return _buildProfilePage();
      case 3:
        return _buildAddressBook();
      default:
        return const SizedBox();
    }
  }

  // ✅ หน้า "รอรับของ"
  Widget _buildReceivePage() {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: kGreen,
          title: const Text(
            "ZapGo",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.black,
            tabs: [
              Tab(text: "รอรับของ"),
              Tab(text: "กำลังขนส่ง"),
              Tab(text: "ขนส่งเสร็จสิ้น"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _animatedTabContent(_buildWaitReceiveTab()),
            _animatedTabContent(_buildDeliveringTab()),
            _animatedTabContent(_buildDeliveredTab()),
          ],
        ),
      ),
    );
  }

  Widget _animatedTabContent(Widget child) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, double value, _) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: child,
        ),
      ),
    );
  }

  Widget _buildWaitReceiveTab() {
    if (_waitLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_waitReceiveItems.isEmpty) {
      return const Center(
        child: Text(
          "ยังไม่มีสินค้ารอรับ 📦",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 10),
        const Text(
          "สินค้าที่ต้องรอรับ",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchWaitReceive,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _waitReceiveItems.length,
              itemBuilder: (context, index) {
                final item = _waitReceiveItems[index];

                // ✅ แปลง base64 → MemoryImage
                ImageProvider imageProvider;
                if (item.pictureProduct.isNotEmpty) {
                  try {
                    final cleaned = item.pictureProduct.replaceAll(
                      RegExp(r'^data:image/[^;]+;base64,'),
                      '',
                    );
                    imageProvider = MemoryImage(base64Decode(cleaned));
                  } catch (_) {
                    imageProvider = const AssetImage(
                      "assets/images/placeholder.png",
                    );
                  }
                } else {
                  imageProvider = const AssetImage(
                    "assets/images/placeholder.png",
                  );
                }

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  shadowColor: Colors.green.withOpacity(0.2),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image(
                        image: imageProvider,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(item.nameProduct),
                    subtitle: Text("จำนวน: ${item.amount}"),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                    onTap: () {
                      // 👉 กดเพื่อไปหน้า DetailProduct พร้อมส่ง deliveryId
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailProduct(
                            deliveryId: item.deliveryId,
                            userid: widget.userid,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveringTab() {
    return Column(
      children: [
        const SizedBox(height: 10),
        const Text(
          "ตำแหน่งของไรเดอร์",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        const Icon(Icons.location_on, color: Colors.red, size: 60),
        const Text("ไรเดอร์กำลังจัดส่งสินค้า"),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildProductCard("IPhone 14 Pro max", 0),
              _buildProductCard("IPhone 14", 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveredTab() {
    return Column(
      children: [
        const SizedBox(height: 10),
        const Text(
          "ได้รับการจัดส่งแล้ว",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [_buildDeliveredCard("IPhone 14 Pro max", 0)],
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(String name, int index) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + index * 100),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: child,
        ),
      ),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        shadowColor: Colors.green.withOpacity(0.2),
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => _buildProductDetailPage(name)),
            );
          },
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset("assets/images/phone_14.png", width: 50),
          ),
          title: const Text("รายละเอียด"),
          subtitle: Text("รุ่น $name\nผู้รับ: ฟ้ามุ่ย\nที่อยู่ผู้รับ: ..."),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildDeliveredCard(String name, int index) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + index * 100),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.scale(scale: value, child: child),
      ),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        shadowColor: Colors.green.withOpacity(0.2),
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Image.asset("assets/images/phone_14.png", width: 50),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("รุ่น $name"),
                    const SizedBox(height: 5),
                    const Text("รายการจัดส่งเสร็จสิ้น ✅"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductDetailPage(String name) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("รายละเอียดของสินค้า"),
        backgroundColor: kGreen,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Image.asset("assets/images/phone_14.png", width: 100),
                ),
                const SizedBox(height: 10),
                Text("ชื่อ: $name"),
                const SizedBox(height: 10),
                const Text("รายละเอียด: ชิป A19, หน้าจอ Super Retina XDR, ..."),
                const SizedBox(height: 10),
                const Text("สถานะ: รอรับของ"),
                const SizedBox(height: 10),
                const Text("ผู้รับ: ฟ้ามุ่ย"),
                const Text(
                  "ที่อยู่: บ้านเลขที่ 11 หมู่ 11 ตำบล 11 จังหวัด 11111",
                ),
                const SizedBox(height: 10),
                const Text("พัสดุ: 200 300"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🏡 หน้า Home
  Widget _buildHomePage(double w) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: kGreen,
          child: Column(
            children: [
              const SizedBox(height: 40),
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, -30 * (1 - value)),
                    child: child,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 🟢 โลโก้ตรงกลาง
                    const Text(
                      "ZapGo",
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    // 🟡 icon ชิดซ้าย
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const UserRecord(),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Image.asset(
                            "assets/images/icon.png",
                            width: 32,
                            height: 32,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutBack,
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: w * 0.30,
                      backgroundColor: Colors.white,
                    ),
                    Image.asset(
                      "assets/images/img_1_cropped.png",
                      width: w * 0.7,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AddDeliveryWork(userIdSender: widget.userid),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    "สร้างงานส่ง",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DeliveryStatusPage(userid: widget.userid),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text(
                    "ยืนยันส่งงาน",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: Container(color: Colors.white)),
      ],
    );
  }

  // 📌 หน้าโปรไฟล์
  Widget _buildProfilePage() {
    if (_userData == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: kGreen,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: const Center(
            child: Text(
              "ZapGo",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(radius: 50, backgroundImage: getProfileImage()),
                const SizedBox(height: 20),
                const Text(
                  "โปรไฟล์ผู้ใช้",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  initialValue: _userData!["name"] ?? "",
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: "ชื่อ",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _userData!["phone"] ?? "",
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: "เบอร์โทร",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => setState(() => _currentIndex = 3),
                        child: const Text(
                          "สมุดที่อยู่",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                            (route) => false,
                          );
                        },
                        child: const Text(
                          "ออกจากระบบ",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 📌 สมุดที่อยู่
  Widget _buildAddressBook() {
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: kGreen,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: const Center(
              child: Text(
                "สมุดที่อยู่",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Expanded(
            child: _addressList == null
                ? const Center(child: CircularProgressIndicator())
                : (_addressList!["count"] == 0
                      ? const Center(
                          child: Text(
                            "คุณยังไม่มีที่อยูในการรับของ",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _addressList!["items"].length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final addr = _addressList!["items"][index];
                            final addressId = addr["address_id"];
                            return TweenAnimationBuilder(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: Duration(
                                milliseconds: 400 + index * 100,
                              ),
                              builder: (context, value, child) => Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: child,
                                ),
                              ),
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                                shadowColor: Colors.green.withOpacity(0.3),
                                child: ListTile(
                                  title: Text(
                                    addr["address"] ?? "ไม่มีข้อมูลที่อยู่",
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "ละติจูด: ${addr["lat"] ?? '-'} , ลองจิจูด: ${addr["lng"] ?? '-'}",
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () async =>
                                        await _deleteAddress(addressId),
                                  ),
                                ),
                              ),
                            );
                          },
                        )),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddAnAddressPage(userId: widget.userid),
                ),
              );
              if (result == true) {
                FetchAddresses(widget.userid);
              }
            },
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              "เพิ่มที่อยู่",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
