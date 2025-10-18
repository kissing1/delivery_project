import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/page/user/sender_detail.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/config/config.dart';

// Requests / Responses
import 'package:flutter_application_1/model/requsts/address_list_post_req.dart';
import 'package:flutter_application_1/model/requsts/delete_addresses_post_req.dart';
import 'package:flutter_application_1/model/responses/delete_addresses_get_res.dart';

// ⚠️ ใช้ alias เพื่อกันชื่อ Item ชนกัน
import 'package:flutter_application_1/model/responses/receiver_by_get_res.dart'
    as rec;
import 'package:flutter_application_1/model/responses/status_transporting_receciver_get_res.dart'
    as tr;
import 'package:flutter_application_1/model/responses/finish_status_deliveries_get_res.dart'
    as fn;
// Pages & Widgets
import 'package:flutter_application_1/page/login.dart';
import 'package:flutter_application_1/page/user/AddAnAddressPage.dart';
import 'package:flutter_application_1/page/user/add_items/Delivery_status.dart';
import 'package:flutter_application_1/page/user/add_items/add_Delivery_work.dart';
import 'package:flutter_application_1/page/user/detail_product.dart';
import 'package:flutter_application_1/page/user/user_%20record.dart';
import 'package:flutter_application_1/widgets/bottom_nav.dart';
// โมเดล finish

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

  // ===== รอรับของ =====
  List<rec.Item> _waitReceiveItems = [];
  bool _waitLoading = false;

  // ===== กำลังขนส่ง =====
  List<tr.Item> _transportingItems = [];
  bool _transportingLoading = false;
  String _lastTransportingDigest = '';

  // ===== ขนส่งเสร็จสิ้น =====
  List<fn.Item> _finishedItems = [];
  bool _finishedLoading = false;
  String _lastFinishedDigest = '';

  // ==== Image cache (ลด decode ซ้ำ/ลด GC) ====
  final Map<int, Uint8List> _imgCache = {};
  static const int _imgCacheMaxEntries = 300; // จำกัดจำนวน entry กันกิน RAM

  Uint8List? _decodeB64Once(String? src) {
    if (src == null || src.isEmpty) return null;
    try {
      if (src.startsWith('http')) return null; // ไม่ใช่ base64
      final cleaned = src.replaceAll(RegExp(r'^data:image/[^;]+;base64,'), '');
      final key = cleaned.hashCode;

      final cached = _imgCache[key];
      if (cached != null) {
        debugPrint('🟢 [IMG] cache HIT key=$key size=${cached.lengthInBytes}B');
        return cached;
      }

      final bytes = base64Decode(cleaned);
      _imgCache[key] = bytes;

      if (_imgCache.length > _imgCacheMaxEntries) {
        debugPrint(
          '⚠️ [IMG] cache overflow: ${_imgCache.length} > $_imgCacheMaxEntries → clear',
        );
        _imgCache.clear();
      }

      debugPrint(
        '🟡 [IMG] cache MISS key=$key decoded=${bytes.lengthInBytes}B',
      );
      return bytes;
    } catch (e) {
      debugPrint('🔴 [IMG] decode error: $e');
      return null;
    }
  }

  ImageProvider _imgFromAny(
    String? src, {
    String asset = "assets/images/no_image.png",
  }) {
    if (src == null || src.isEmpty) return AssetImage(asset);
    if (src.startsWith('http')) return NetworkImage(src);
    final bytes = _decodeB64Once(src);
    return bytes != null ? MemoryImage(bytes) : AssetImage(asset);
  }

  @override
  void initState() {
    super.initState();
    Configuration.getConfig().then((cfg) {
      setState(() => _apiBase = (cfg['apiEndpoint'] as String?)?.trim());

      FetchUser(widget.userid);
      FetchAddresses(widget.userid);

      _fetchWaitReceive(); // โหลดแท็บ "รอรับของ" ครั้งแรก
      _fetchTransporting(); // โหลดแท็บ "กำลังขนส่ง" ครั้งแรก
      _startAutoCheck();
      _fetchFinished(); // ✅ เช็คอัปเดตอัตโนมัติ
    });
  }

  @override
  void dispose() {
    _waitCheckTimer?.cancel(); // ✅ ยกเลิก Timer ตอนออก
    super.dispose();
  }

  void _startAutoCheck() {
    _waitCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _checkForUpdates(); // รอรับของ
      await _fetchTransporting(force: true);
      await _fetchFinished(force: true); // กำลังขนส่ง (ไม่แสดงโหลด)
    });
  }

  /// ✅ ใช้กับ "รอรับของ" — setState เฉพาะตอนข้อมูลเปลี่ยนจริง
  Future<void> _checkForUpdates() async {
    if (_apiBase == null) return;
    try {
      final url = Uri.parse(
        "$_apiBase/deliveries/by-receiver/${widget.userid}",
      );
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final parsed = rec.byReceiverGetResFromJson(res.body);
        if (!_waitListEquals(parsed.items, _waitReceiveItems)) {
          debugPrint('🟡 [WAIT] data changed → rebuild');
          if (!mounted) return;
          setState(() => _waitReceiveItems = parsed.items);
        } else {
          debugPrint('🟢 [WAIT] no change → skip setState');
        }
      }
    } catch (e) {
      debugPrint("❌ update check error: $e");
    }
  }

  /// ✅ เทียบรายการ “รอรับของ” ว่ามีการเปลี่ยนแปลงหรือไม่
  bool _waitListEquals(List<rec.Item> a, List<rec.Item> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].amount != b[i].amount ||
          a[i].deliveryId != b[i].deliveryId) {
        return false;
      }
    }
    return true;
  }

  // ===== APIs: รอรับของ =====
  Future<void> _fetchWaitReceive() async {
    if (_apiBase == null) return;
    setState(() => _waitLoading = true);
    try {
      final url = Uri.parse(
        "$_apiBase/deliveries/by-receiver/${widget.userid}",
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final parsed = rec.byReceiverGetResFromJson(res.body);
        setState(() => _waitReceiveItems = parsed.items);
      }
    } catch (e) {
      debugPrint("❌ fetch wait receive error: $e");
    } finally {
      setState(() => _waitLoading = false);
    }
  }

  // ===== APIs: กำลังขนส่ง =====
  String _transportingDigest(List<tr.Item> list) {
    final b = StringBuffer();
    for (final it in list) {
      b.writeAll([
        it.deliveryId,
        it.status,
        it.amount,
        it.nameProduct,
        it.pictureProduct.hashCode,
        it.assignments.isNotEmpty
            ? it.assignments.first.pictureStatus2.hashCode
            : 0,
        it.assignments.isNotEmpty && it.assignments.first.pictureStatus3 != null
            ? it.assignments.first.pictureStatus3.toString().hashCode
            : 0,
      ], '|');
      b.write('||');
    }
    return b.toString();
  }

  String _finishedDigest(List<fn.Item> list) {
    final b = StringBuffer();
    for (final it in list) {
      b.writeAll([
        it.deliveryId,
        it.status,
        it.amount,
        it.nameProduct,
        it.pictureProduct.hashCode,
        it.assignments.isNotEmpty
            ? it.assignments.first.pictureStatus2.hashCode
            : 0,
        it.assignments.isNotEmpty
            ? it.assignments.first.pictureStatus3.hashCode
            : 0,
      ], '|');
      b.write('||');
    }
    return b.toString();
  }

  Future<void> _fetchTransporting({bool force = false}) async {
    if (_apiBase == null) return;
    if (!force) setState(() => _transportingLoading = true);
    try {
      final url = Uri.parse(
        "$_apiBase/deliveries/status-transporting/${widget.userid}",
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final parsed = tr.statusTransportingRececiverGetResFromJson(res.body);
        final newItems = parsed.items;
        final newDigest = _transportingDigest(newItems);

        if (newDigest != _lastTransportingDigest) {
          debugPrint('🟡 [TRANSPORTING] data changed → rebuild');
          if (!mounted) return;
          setState(() {
            _transportingItems = newItems;
            _lastTransportingDigest = newDigest;
          });
        } else {
          debugPrint('🟢 [TRANSPORTING] no change → skip setState');
        }
      }
    } catch (e) {
      debugPrint("❌ fetch transporting error: $e");
    } finally {
      if (!force && mounted) setState(() => _transportingLoading = false);
    }
  }

  // วางฟังก์ชันนี้ตรงนี้ได้เลย (อยู่ในคลาสเดียวกัน)
  void _openSenderDetail({required int deliveryId, required int? riderId}) {
    if (!mounted) return;

    if (riderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยังไม่พบข้อมูลไรเดอร์ของงานนี้')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SenderDetail(
          deliveryId: deliveryId, // ✅ ใช้ค่าจากพารามิเตอร์
          riderId: riderId, // ✅ ใช้ค่าจากพารามิเตอร์
          userId: widget.userid,
        ),
      ),
    );
  }

  Future<void> _fetchFinished({bool force = false}) async {
    if (_apiBase == null) return;
    if (!force) setState(() => _finishedLoading = true);
    try {
      final url = Uri.parse(
        '$_apiBase/deliveries/status-finish/${widget.userid}',
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final parsed = fn.finishStatusDeliveriesGetResFromJson(res.body);
        final newItems = parsed.items;
        final newDigest = _finishedDigest(newItems);

        if (newDigest != _lastFinishedDigest) {
          setState(() {
            _finishedItems = newItems.cast<fn.Item>();
            _lastFinishedDigest = newDigest;
          });
        }
      } else {
        debugPrint('❌ finish fetch http ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ finish fetch error: $e');
    } finally {
      if (!force) setState(() => _finishedLoading = false);
    }
  }

  // ===== Users / Addresses =====
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
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("ลบที่อยู่สำเร็จ ✅")));
          await FetchAddresses(widget.userid);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(data.message)));
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("เกิดข้อผิดพลาด: $e")));
    }
  }

  // ===================================================================
  // UI
  // ===================================================================
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

  // ----- Tab: รอรับของ -----
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

  // ----- Tab: กำลังขนส่ง (UI เหมือนตัวอย่างรูป) -----
  Widget _buildDeliveringTab() {
    if (_transportingLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_transportingItems.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _fetchTransporting(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text(
                "ยังไม่มีสินค้าที่กำลังขนส่ง 🚚",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchTransporting(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _transportingItems.length,
        itemBuilder: (context, index) {
          final item = _transportingItems[index];

          ImageProvider _imgFromBase64(
            String? b64, {
            String placeholder = "assets/images/no_image.png",
          }) {
            if (b64 == null || b64.isEmpty) {
              return AssetImage(placeholder);
            }
            try {
              final cleaned = b64.replaceAll(
                RegExp(r'^data:image/[^;]+;base64,'),
                '',
              );
              return MemoryImage(base64Decode(cleaned));
            } catch (_) {
              return AssetImage(placeholder);
            }
          }

          final productImg = _imgFromBase64(
            item.pictureProduct,
            placeholder: "assets/images/placeholder.png",
          );

          final pic2 = (item.assignments.isNotEmpty)
              ? _imgFromBase64(item.assignments.first.pictureStatus2)
              : const AssetImage("assets/images/no_image.png");

          final pic3 =
              (item.assignments.isNotEmpty &&
                  item.assignments.first.pictureStatus3 != null)
              ? _imgFromBase64(item.assignments.first.pictureStatus3.toString())
              : const AssetImage("assets/images/no_image.png");

          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 350 + index * 80),
            curve: Curves.easeOutCubic,
            builder: (context, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, 16 * (1 - v)),
                child: child,
              ),
            ),
            child: Card(
              color: const Color(0xFFF7FAF7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
              shadowColor: Colors.green.withOpacity(0.25),
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: รูป + ข้อความ
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image(
                            image: productImg,
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.nameProduct, // ← ใช้ name_product จากโมเดล
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis, // กันชื่อยาวล้น
                              ),
                              Text(
                                "สถานะ: ${item.status}",
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                "จำนวน: ${item.amount}",
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    const Divider(height: 20),

                    // หัวข้อรายละเอียด
                    InkWell(
                      onTap: () {
                        final int deliveryId = item.deliveryId;
                        final int? riderId = item.assignments.isNotEmpty
                            ? item.assignments.first.riderId
                            : null;

                        _openSenderDetail(
                          deliveryId: deliveryId,
                          riderId: riderId,
                        );
                      },
                      child: Row(
                        children: const [
                          Text(
                            "รายละเอียดของผู้จัดส่ง",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: Colors.orange,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // รูป 2 ช่องเท่ากัน
                    Row(
                      children: [
                        Expanded(child: _imageCell(pic2, "รูปตอนรับของ")),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _imageCell(pic3, "รูปตอนส่งของจริงสิ้น"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // กล่องรูป + ข้อความใต้ภาพ
  Widget _imageCell(ImageProvider img, String caption) {
    final isAssetNoImg =
        img is AssetImage && (img.assetName.contains("no_image"));

    return Column(
      children: [
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE9ECE8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image(image: img, fit: BoxFit.cover),
                if (isAssetNoImg)
                  const Center(
                    child: Text(
                      "ยังไม่มีรูป",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          caption,
          style: const TextStyle(fontSize: 12.5, color: Colors.black87),
        ),
      ],
    );
  }

  // ----- Tab: ขนส่งเสร็จสิ้น (placeholder) -----
  Widget _buildDeliveredTab() {
    ImageProvider _imgFromBase64(
      String? b64, {
      String placeholder = 'assets/images/no_image.png',
    }) {
      if (b64 == null || b64.isEmpty) return AssetImage(placeholder);
      try {
        final cleaned = b64.replaceAll(
          RegExp(r'^data:image/[^;]+;base64,'),
          '',
        );
        return MemoryImage(base64Decode(cleaned));
      } catch (_) {
        return AssetImage(placeholder);
      }
    }

    if (_finishedLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_finishedItems.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _fetchFinished(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text(
                'ยังไม่มีงานที่ส่งเสร็จสิ้น 📦✅',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchFinished(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _finishedItems.length,
        itemBuilder: (context, index) {
          final item = _finishedItems[index];

          final productImg = _imgFromBase64(
            item.pictureProduct,
            placeholder: 'assets/images/placeholder.png',
          );

          final pic2 = (item.assignments.isNotEmpty)
              ? _imgFromBase64(item.assignments.first.pictureStatus2)
              : const AssetImage('assets/images/no_image.png');

          final pic3 = (item.assignments.isNotEmpty)
              ? _imgFromBase64(item.assignments.first.pictureStatus3)
              : const AssetImage('assets/images/no_image.png');

          // การ์ดสรุป (เหมือนรูปตัวอย่าง finish ✅)
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 350 + index * 80),
            curve: Curves.easeOutCubic,
            builder: (context, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, 14 * (1 - v)),
                child: child,
              ),
            ),
            child: Card(
              color: const Color(0xFFF7FAF7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
              shadowColor: Colors.green.withOpacity(0.25),
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: รูปสินค้า + ชื่อ + สถานะ finish ✅
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image(
                            image: productImg,
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.nameProduct, // ใช้ชื่อสินค้าจริง
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                children: const [
                                  Text(
                                    'สถานะ: finish  ',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                ],
                              ),
                              Text(
                                'จำนวน: ${item.amount}',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    const Divider(height: 20),

                    // หัวข้อ "รายละเอียดผู้จัดส่ง" + ติ๊กเขียว
                    Row(
                      children: const [
                        Text(
                          'รายละเอียดผู้จัดส่ง',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.check_circle, size: 18, color: Colors.green),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // รูป 2 ช่องเท่ากัน: pictureStatus2 / pictureStatus3
                    Row(
                      children: [
                        Expanded(child: _imageCell(pic2, 'รูปตอนรับของ')),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _imageCell(pic3, 'รูปตอนส่งของเสร็จสิ้น'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
                    const Text(
                      "ZapGo",
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserRecord(
                                userIdSender:
                                    widget.userid, // ผู้ใช้คนนี้ในบทบาทผู้รับ
                                // ถ้าไม่จำเป็นจะยังไม่ส่ง
                              ),
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
        const Expanded(child: SizedBox()),
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
