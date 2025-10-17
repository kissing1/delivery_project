import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/config/config.dart';
import 'package:flutter_application_1/model/requsts/Deliveryadd_create_post_req.dart';
import 'package:flutter_application_1/model/responses/Deliveryadd_create_post_res.dart';
import 'package:flutter_application_1/model/responses/by_list_sender_get_res.dart'
    as senderlist;
import 'package:flutter_application_1/page/user/add_items/rider_detail.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/providers/delivery_provider.dart';
import 'package:flutter_application_1/page/user/add_items/delivery_detail_page.dart';
import 'package:http/http.dart' as http;

/// ===== helpers สำหรับอ่าน/เช็คสถานะ =====
String _statusOf(dynamic item) {
  // รองรับทั้ง model (มี d.status) และ map จาก API (มี d["status"])
  final s = (item is Map)
      ? (item["status"] ?? "").toString()
      : (item.status ?? "").toString();
  return s.toLowerCase().trim();
}

// ignore: unused_element
bool _isTransporting(dynamic item) => _statusOf(item) == "transporting";

// ignore: unused_element
bool _isFinished(dynamic item) {
  final s = _statusOf(item);
  // เผื่อ backend ใช้คำสะกดต่างกัน
  return s == "finish" || s == "finished" || s == "done" || s == "completed";
}

class DeliveryStatusPage extends StatefulWidget {
  final int userid;
  const DeliveryStatusPage({super.key, required this.userid});

  @override
  State<DeliveryStatusPage> createState() => _DeliveryStatusPageState();
}

class _DeliveryStatusPageState extends State<DeliveryStatusPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _apiBase;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cfg = await Configuration.getConfig();
      if (!mounted) return;
      setState(() => _apiBase = cfg["apiEndpoint"]);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_apiBase == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF32BD6C),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "ZapGo",
          style: TextStyle(
            fontFamily: "Poppins",
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.white,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontFamily: "Poppins"),
          tabs: const [
            Tab(text: "ทั้งหมด"),
            Tab(text: "รอผู้ส่ง"),
            Tab(text: "กำลังขนส่ง"),
            Tab(text: "ขนส่งเสร็จสิ้น"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // AllWidget ต้องการ apiBase เฉยๆ ข้างในค่อยอ่าน Provider เอง
          AllWidget(apiBase: _apiBase!),

          // WaitingWidget ดึงข้อมูลเองจาก API → ไม่ต้อง rebuild ตาม Provider
          WaitingWidget(userid: widget.userid),

          // เฉพาะสองแท็บนี้ที่ต้องใช้ deliveries → ใช้ Consumer จำกัด scope rebuild
          Consumer<DeliveryProvider>(
            builder: (_, p, __) => ShippingWidget(
              deliveries: p.deliveries,
              userid: widget.userid, // <<<< เพิ่มบรรทัดนี้
            ),
          ),
          Consumer<DeliveryProvider>(
            builder: (_, p, __) =>
                DoneWidget(deliveries: p.deliveries, userid: widget.userid),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// 🟢 Widget “ทั้งหมด” (ใช้ข้อมูลจาก Provider)
class AllWidget extends StatelessWidget {
  final String apiBase;
  const AllWidget({super.key, required this.apiBase});

  @override
  Widget build(BuildContext context) {
    final deliveries = context.watch<DeliveryProvider>().deliveries;

    if (deliveries.isEmpty) {
      return const Center(
        child: Text(
          "ยังไม่มีสินค้าที่จะส่ง",
          style: TextStyle(fontFamily: "Roboto", fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      key: const PageStorageKey<String>('all-list'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: deliveries.length + 1,
      itemBuilder: (context, index) {
        if (index == deliveries.length) {
          // ✅ ปุ่มยืนยันทั้งหมด
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: ElevatedButton.icon(
                icon: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 20,
                ),
                label: const Text(
                  "ยืนยันทั้งหมด",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Poppins",
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  minimumSize: const Size(180, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  if (deliveries.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("ไม่มีข้อมูลที่จะส่ง"),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  try {
                    for (final d in deliveries) {
                      final body = deliveryCreatePostReqToJson(
                        DeliveryCreatePostReq(
                          userIdSender: d.userIdSender,
                          userIdReceiver: d.userIdReceiver,
                          phoneReceiver: d.phoneReceiver,
                          addressIdSender: d.addressIdSender,
                          addressIdReceiver: d.addressIdReceiver,
                          nameProduct: d.nameProduct,
                          detailProduct: d.detailProduct,
                          pictureProduct: d.pictureProduct,
                          amount: d.amount,
                          status: d.status,
                        ),
                      );

                      final res = await http.post(
                        Uri.parse("$apiBase/delivery/create"),
                        headers: {"Content-Type": "application/json"},
                        body: body,
                      );

                      if (res.statusCode == 200) {
                        final data = deliveryCreatePostResFromJson(res.body);
                        debugPrint("✅ ส่งสำเร็จ: ${data.delivery.nameProduct}");
                      } else {
                        debugPrint("❌ ส่งไม่สำเร็จ: ${res.statusCode}");
                      }
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("ส่งข้อมูลสำเร็จ!"),
                        backgroundColor: Colors.green,
                      ),
                    );

                    context.read<DeliveryProvider>().clearAll();
                  } catch (e) {
                    debugPrint("❌ Error: $e");
                  }
                },
              ),
            ),
          );
        }

        final d = deliveries[index];
        return _deliveryCard(context, d);
      },
    );
  }

  Widget _deliveryCard(BuildContext context, dynamic d) {
    final provider = context.read<DeliveryProvider>();
    final index = provider.deliveries.indexOf(d);

    return Stack(
      children: [
        InkWell(
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => DeliveryDetailPage(
                  deliveryData: d.toJson(),
                  deliveryId: d.id,
                ),
              ),
            );
          },
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.black12),
            ),
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (d.pictureProduct.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        const Base64Decoder().convert(d.pictureProduct),
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        gaplessPlayback: true, // ✅ ลดกระพริบรูป
                      ),
                    )
                  else
                    const Icon(Icons.inventory, size: 70, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.nameProduct,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: "Poppins",
                          ),
                        ),
                        Text("จำนวน: ${d.amount}"),
                        Text("ผู้รับ: ${d.receiverName ?? '-'}"),
                        Text("ที่อยู่ผู้รับ: ${d.receiverAddress ?? '-'}"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 🗑️ ปุ่มลบมุมขวาบน
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: "ลบรายการนี้",
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("ลบรายการนี้?"),
                  content: Text(
                    "คุณต้องการลบ \"${d.nameProduct}\" ออกจากรายการหรือไม่",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("ยกเลิก"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        provider.removeAt(index);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("ลบ ${d.nameProduct} แล้ว"),
                            backgroundColor: Colors.redAccent,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      child: const Text("ลบ"),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// 🟡 Widget “รอผู้ส่ง” (ดึงข้อมูลจาก API delivery/list-by-user)
class WaitingWidget extends StatefulWidget {
  // ดึงข้อมูลเองจาก API → ไม่ต้องรับ deliveries จากภายนอก
  final int userid;

  const WaitingWidget({super.key, required this.userid});

  @override
  State<WaitingWidget> createState() => _WaitingWidgetState();
}

class _WaitingWidgetState extends State<WaitingWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // ✅ คง state ของแท็บนี้

  String? _apiBase;
  List<dynamic> _userDeliveries = [];
  bool _isLoading = true;
  bool _isFetching = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadConfigAndFetch();

    // 🔁 รีเฟรชทุก 10 วินาที (เช็ค mounted และไม่ยิงซ้ำ)
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (mounted && !_isFetching) {
        await _fetchDeliveriesByUser();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadConfigAndFetch() async {
    final cfg = await Configuration.getConfig();
    if (!mounted) return;
    setState(() => _apiBase = cfg["apiEndpoint"]);
    await _fetchDeliveriesByUser();
  }

  Future<void> _fetchDeliveriesByUser() async {
    if (_apiBase == null || _isFetching) return;

    _isFetching = true;
    try {
      final res = await http.post(
        Uri.parse("$_apiBase/delivery/list-by-user"),
        headers: {"Content-Type": "application/json; charset=utf-8"},
        body: jsonEncode({"user_id_sender": widget.userid}),
      );

      if (res.statusCode == 200) {
        // ✅ ป้องกัน error type 'Null'
        if (res.body.isEmpty || res.body == 'null') {
          debugPrint("⚠️ API ส่ง null/ว่าง");
          if (mounted) {
            setState(() {
              _userDeliveries = [];
              _isLoading = false;
            });
          }
          return;
        }

        final decoded = jsonDecode(res.body);
        if (decoded is! Map<String, dynamic>) {
          debugPrint("⚠️ Response format ไม่ถูกต้อง: $decoded");
          return;
        }

        final newList = List.from(decoded["deliveries"] ?? []);
        final oldJson = jsonEncode(_userDeliveries);
        final newJson = jsonEncode(newList);

        if (oldJson != newJson) {
          if (mounted) {
            setState(() {
              _userDeliveries = newList;
              _isLoading = false;
            });
          }
        } else {
          if (_isLoading && mounted) {
            setState(() => _isLoading = false);
          }
        }
      } else {
        debugPrint("❌ API Error: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Exception: $e");
    } finally {
      _isFetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required เมื่อใช้ keepAlive

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // กรองให้เหลือเฉพาะ “ยังรอผู้ส่ง” (ไม่รวม transporting/finish)
    final filtered = _userDeliveries.where((e) {
      final s = _statusOf(e);
      return s != "transporting" &&
          s != "finish" &&
          s != "finished" &&
          s != "done" &&
          s != "completed";
    }).toList();

    if (filtered.isEmpty) {
      return const Center(
        child: Text(
          "ยังไม่มีรายการรอผู้ส่ง",
          style: TextStyle(fontFamily: "Poppins", fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchDeliveriesByUser,
      child: ListView.builder(
        key: const PageStorageKey<String>('waiting-list'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final d = filtered[index];
          final status = _statusOf(d);

          return Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.black12),
            ),
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: (d["picture_product"] ?? "").toString().isNotEmpty
                  ? Image.memory(
                      const Base64Decoder().convert(
                        (d["picture_product"] as String).replaceAll(
                          RegExp(r'^data:image/[^;]+;base64,'),
                          '',
                        ),
                      ),
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      gaplessPlayback: true, // ✅ ลดการกะพริบของรูป
                    )
                  : const Icon(Icons.inventory, size: 60, color: Colors.grey),
              title: Text(
                "ชื่อสินค้า: ${(d["name_product"] ?? "ไม่ทราบชื่อสินค้า")}",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Poppins",
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("สถานะ: ${d["status"] ?? "-"}"),
                  if (d["amount"] != null) Text("จำนวน: ${d["amount"]}"),
                ],
              ),
              trailing: status == "accept"
                  ? const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 28,
                    )
                  : const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// 🟠 Widget “กำลังขนส่ง”
/// ─────────────────────────────────────────────────────────────────────────
/// 🟠 Widget “กำลังขนส่ง”
class ShippingWidget extends StatefulWidget {
  final List deliveries; // จาก Provider (อาจเป็น model ของคุณหรือ Map)
  final int? userid; // ถ้าส่ง userid มาจะยิง API list-by-user เพิ่ม

  const ShippingWidget({super.key, required this.deliveries, this.userid});

  @override
  State<ShippingWidget> createState() => _ShippingWidgetState();
}

class _ShippingWidgetState extends State<ShippingWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String? _apiBase;
  bool _loading = false;
  List<senderlist.Delivery> _apiTransporting = [];
  String _lastJson = ""; // 🧠 เก็บ snapshot ล่าสุด
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initApiBaseAndMaybeFetch();

    // 🔁 รีเฟรชทุก 10 วินาทีแบบไม่กระพริบ
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !_loading) {
        _fetchTransportingFromApi();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initApiBaseAndMaybeFetch() async {
    if (widget.userid == null) return;
    final cfg = await Configuration.getConfig();
    if (!mounted) return;
    setState(() => _apiBase = (cfg["apiEndpoint"] as String?)?.trim());
    await _fetchTransportingFromApi();
  }

  Future<void> _fetchTransportingFromApi() async {
    if (_apiBase == null || widget.userid == null || _loading) return;

    _loading = true;
    try {
      final res = await http.post(
        Uri.parse("$_apiBase/delivery/list-by-user"),
        headers: const {"Content-Type": "application/json; charset=utf-8"},
        body: jsonEncode({"user_id_sender": widget.userid}),
      );

      if (res.statusCode == 200) {
        if (res.body.isEmpty || res.body == 'null') {
          debugPrint("⚠️ list-by-user ส่ง null/empty");
          if (mounted && _apiTransporting.isNotEmpty) {
            setState(() => _apiTransporting = []);
          }
          return;
        }

        final parsed = senderlist.byListSenderGetResFromJson(res.body);

        bool isTransporting(String? s) {
          final x = (s ?? '').toLowerCase().trim();
          return x == 'transporting' || x == 'shipping';
        }

        final onlyTransporting = parsed.deliveries
            .where((d) => isTransporting(d.status))
            .toList();

        final newJson = jsonEncode(
          onlyTransporting.map((e) => e.toJson()).toList(),
        );
        if (newJson == _lastJson) {
          debugPrint("ℹ️ ไม่มีการเปลี่ยนแปลงของข้อมูล shipping");
          return;
        }

        debugPrint("✅ ข้อมูล shipping มีการเปลี่ยนแปลง → อัปเดต UI");

        if (mounted) {
          setState(() {
            _apiTransporting = onlyTransporting;
            _lastJson = newJson;
          });
        }
      } else {
        debugPrint("❌ list-by-user error ${res.statusCode}: ${res.body}");
      }
    } catch (e) {
      debugPrint("❌ list-by-user exception: $e");
    } finally {
      _loading = false;
    }
  }

  // ---------- helpers ----------
  String _stripHeader(String raw) =>
      raw.replaceAll(RegExp(r'^data:image/[^;]+;base64,'), '').trim();

  String _keyOf(dynamic d) {
    try {
      if (d is Map && d["delivery_id"] != null) return "m:${d["delivery_id"]}";
      if (d is senderlist.Delivery) return "a:${d.deliveryId}";
      final did = (d.deliveryId ?? d.id ?? "").toString();
      return "p:$did";
    } catch (_) {
      return d.hashCode.toString();
    }
  }

  String _nameOf(dynamic d) {
    if (d is Map) return (d["name_product"] ?? "-").toString();
    if (d is senderlist.Delivery) return d.nameProduct;
    return d.nameProduct ?? "-";
  }

  String _statusOfAny(dynamic d) {
    if (d is Map) return (d["status"] ?? "").toString();
    if (d is senderlist.Delivery) return d.status;
    return d.status?.toString() ?? "";
  }

  int _amountOf(dynamic d) {
    if (d is Map) return (d["amount"] ?? 0) as int;
    if (d is senderlist.Delivery) return d.amount;
    return d.amount ?? 0;
  }

  String _pictureProductB64(dynamic d) {
    final raw = (d is Map)
        ? (d["picture_product"] ?? "").toString()
        : (d is senderlist.Delivery)
        ? d.pictureProduct
        : (d.pictureProduct ?? "");
    return _stripHeader(raw);
  }

  String? _proofB64(String? s) {
    if (s == null) return null;
    final b64 = _stripHeader(s);
    return b64.isEmpty ? null : b64;
  }

  Widget _placeholderBox({
    double w = 120,
    double h = 120,
    String text = "ยังไม่มีรูป",
  }) {
    return Container(
      width: w,
      height: h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black26),
        color: Colors.grey.shade100,
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: Colors.grey),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _b64ImageBox(
    String b64, {
    double w = 120,
    double h = 120,
    BoxFit fit = BoxFit.cover,
  }) {
    try {
      final bytes = const Base64Decoder().convert(b64);
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          bytes,
          width: w,
          height: h,
          fit: fit,
          gaplessPlayback: true,
        ),
      );
    } catch (_) {
      return _placeholderBox(w: w, h: h, text: "รูปไม่ถูกต้อง");
    }
  }

  Widget _buildProofRow(senderlist.Delivery d) {
    final pic2 = _proofB64(d.proof.pictureStatus2);
    final pic3 = _proofB64(d.proof.pictureStatus3);

    Widget item(String? b64, String label) {
      return Column(
        children: [
          b64 != null
              ? _b64ImageBox(b64, w: 120, h: 120)
              : _placeholderBox(w: 120, h: 120),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: "Poppins",
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        item(pic2, "รูปตอนรับของ"),
        const SizedBox(width: 16),
        item(pic3, "รูปตอนส่งของเสร็จสิ้น"),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final providerShipping = widget.deliveries.where((it) {
      final s = _statusOfAny(it).toLowerCase().trim();
      return s == 'transporting' || s == 'shipping';
    }).toList();

    final combined = <dynamic>[];
    final seen = <String>{};
    void addUnique(dynamic item) {
      final k = _keyOf(item);
      if (!seen.contains(k)) {
        seen.add(k);
        combined.add(item);
      }
    }

    for (final a in _apiTransporting) addUnique(a);
    for (final p in providerShipping) addUnique(p);

    if (_loading && combined.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (combined.isEmpty) {
      return const Center(
        child: Text(
          "ยังไม่มีรายการกำลังขนส่ง",
          style: TextStyle(fontFamily: "Poppins", fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchTransportingFromApi,
      child: ListView.builder(
        key: const PageStorageKey<String>('shipping-list'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: combined.length,
        itemBuilder: (context, index) {
          final d = combined[index];
          final isApiModel = d is senderlist.Delivery;

          final name = _nameOf(d);
          final status = _statusOfAny(d);
          final amount = _amountOf(d);
          final prodB64 = _pictureProductB64(d);
          final hasProdPic = prodB64.isNotEmpty;

          return GestureDetector(
            onTap: () {
              if (isApiModel) {
                // ignore: unnecessary_cast
                final delivery = d as senderlist.Delivery;
                final int? riderId = (delivery.assignments.isNotEmpty)
                    ? delivery.assignments.first.riderId
                    : null;
                final deliveryId = delivery.deliveryId;

                if (riderId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RiderDetail(
                        riderId: riderId,
                        deliveryId: deliveryId,
                        userid: widget.userid,
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("ยังไม่มีไรเดอร์รับงานนี้"),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.black12),
              ),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        hasProdPic
                            ? _b64ImageBox(prodB64, w: 60, h: 60)
                            : const Icon(
                                Icons.local_shipping,
                                size: 60,
                                color: Colors.green,
                              ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: "Poppins",
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text("สถานะ: $status"),
                              Text("จำนวน: $amount"),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    if (isApiModel) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: const [
                          Text(
                            "รายละเอียดของผู้จัดส่ง",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: "Poppins",
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.orange,
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // ignore: unnecessary_cast
                      _buildProofRow(d as senderlist.Delivery),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// 🔵 Widget “ขนส่งเสร็จสิ้น”
class DoneWidget extends StatefulWidget {
  final List deliveries;
  final int? userid; // ถ้าส่ง userid มาจะยิง API มารวมด้วย

  const DoneWidget({super.key, required this.deliveries, this.userid});

  @override
  State<DoneWidget> createState() => _DoneWidgetState();
}

class _DoneWidgetState extends State<DoneWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String? _apiBase;
  bool _loading = false;
  List<senderlist.Delivery> _apiDone = []; // จาก API (status = finish)

  @override
  void initState() {
    super.initState();
    _initApiBaseAndMaybeFetch();
  }

  Future<void> _initApiBaseAndMaybeFetch() async {
    if (widget.userid == null) return;
    final cfg = await Configuration.getConfig();
    if (!mounted) return;
    setState(() => _apiBase = (cfg["apiEndpoint"] as String?)?.trim());
    await _fetchDoneFromApi();
  }

  bool _isFinishedStr(String? s) {
    final x = (s ?? '').toLowerCase().trim();
    return x == 'finish' || x == 'finished' || x == 'done' || x == 'completed';
  }

  Future<void> _fetchDoneFromApi() async {
    if (_apiBase == null || widget.userid == null || _loading) return;

    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse("$_apiBase/delivery/list-by-user"),
        headers: const {"Content-Type": "application/json; charset=utf-8"},
        body: jsonEncode({"user_id_sender": widget.userid}),
      );

      if (res.statusCode == 200) {
        if (res.body.isEmpty || res.body == 'null') {
          debugPrint("⚠️ list-by-user ส่ง null/empty");
          if (mounted) setState(() => _apiDone = []);
          return;
        }

        final parsed = senderlist.byListSenderGetResFromJson(res.body);
        final onlyDone = parsed.deliveries
            .where((d) => _isFinishedStr(d.status))
            .toList();
        if (mounted) setState(() => _apiDone = onlyDone);
      } else {
        debugPrint("❌ list-by-user error ${res.statusCode}: ${res.body}");
      }
    } catch (e) {
      debugPrint("❌ list-by-user exception: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- helpers: รวม/อ่านค่าจากหลายชนิด ----------
  String _keyOf(dynamic d) {
    try {
      if (d is Map && d["delivery_id"] != null) return "m:${d["delivery_id"]}";
      if (d is senderlist.Delivery) return "a:${d.deliveryId}";
      final did = (d.deliveryId ?? d.id ?? "").toString();
      return "p:$did";
    } catch (_) {
      return d.hashCode.toString();
    }
  }

  String _nameOf(dynamic d) {
    if (d is Map) return (d["name_product"] ?? "-").toString();
    if (d is senderlist.Delivery) return d.nameProduct;
    return d.nameProduct ?? "-";
  }

  String _statusOfAny(dynamic d) {
    if (d is Map) return (d["status"] ?? "").toString();
    if (d is senderlist.Delivery) return d.status;
    return d.status?.toString() ?? "";
  }

  int _amountOf(dynamic d) {
    if (d is Map) return (d["amount"] ?? 0) as int;
    if (d is senderlist.Delivery) return d.amount;
    return d.amount ?? 0;
  }

  String _stripHeader(String raw) =>
      raw.replaceAll(RegExp(r'^data:image/[^;]+;base64,'), '').trim();

  String _pictureProductB64(dynamic d) {
    final raw = (d is Map)
        ? (d["picture_product"] ?? "").toString()
        : (d is senderlist.Delivery)
        ? d.pictureProduct
        : (d.pictureProduct ?? "");
    return _stripHeader(raw);
  }

  String? _pictureStatus2B64(senderlist.Delivery d) {
    String? candidate = d.proof.pictureStatus2;
    candidate ??= d.assignments
        .map((a) => a.pictureStatus2)
        .where((e) => (e ?? '').trim().isNotEmpty)
        .fold<String?>(null, (prev, e) => e);
    if (candidate == null || candidate.trim().isEmpty) return null;
    return _stripHeader(candidate);
  }

  List<String> _pictureStatus3ListB64(senderlist.Delivery d) {
    final set = <String>{};
    void addIf(String? s) {
      if (s == null) return;
      final b64 = _stripHeader(s);
      if (b64.isNotEmpty) set.add(b64);
    }

    addIf(d.proof.pictureStatus3);
    for (final a in d.assignments) addIf(a.pictureStatus3);
    return set.toList();
  }

  Widget _placeholderBox({
    double w = 72,
    double h = 72,
    String text = "ยังไม่มีรูป",
  }) {
    return Container(
      width: w,
      height: h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
        color: Colors.grey.shade100,
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, color: Colors.grey),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _b64ImageBox(
    String b64, {
    double w = 72,
    double h = 72,
    BoxFit fit = BoxFit.cover,
  }) {
    try {
      final bytes = const Base64Decoder().convert(b64);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          width: w,
          height: h,
          fit: fit,
          gaplessPlayback: true,
        ),
      );
    } catch (_) {
      return _placeholderBox(w: w, h: h, text: "รูปไม่ถูกต้อง");
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final providerDone = widget.deliveries
        .where((it) => _isFinishedStr(_statusOfAny(it)))
        .toList();

    final combined = <dynamic>[];
    final seen = <String>{};
    void addUnique(dynamic item) {
      final k = _keyOf(item);
      if (!seen.contains(k)) {
        seen.add(k);
        combined.add(item);
      }
    }

    for (final a in _apiDone) addUnique(a);
    for (final p in providerDone) addUnique(p);

    if (_loading && combined.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (combined.isEmpty) {
      return const Center(
        child: Text(
          "ยังไม่มีรายการขนส่งเสร็จสิ้น",
          style: TextStyle(fontFamily: "Poppins", fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchDoneFromApi,
      child: ListView.builder(
        key: const PageStorageKey<String>('done-list'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: combined.length,
        itemBuilder: (context, index) {
          final d = combined[index];
          final isApiModel = d is senderlist.Delivery;

          final name = _nameOf(d);
          final status = _statusOfAny(d);
          final amount = _amountOf(d);
          final prodB64 = _pictureProductB64(d);
          final hasProdPic = prodB64.isNotEmpty;

          String? pic2;
          List<String> pics3 = const [];
          if (isApiModel) {
            // ignore: unnecessary_cast
            pic2 = _pictureStatus2B64(d as senderlist.Delivery);
            pics3 = _pictureStatus3ListB64(d);
          }

          return Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.black12),
            ),
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // แถวข้อมูลหลัก
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      hasProdPic
                          ? _b64ImageBox(prodB64, w: 60, h: 60)
                          : const Icon(
                              Icons.check_circle,
                              size: 60,
                              color: Colors.blue,
                            ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                fontFamily: "Poppins",
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text("สถานะ: $status ✅"),
                            Text("จำนวน: $amount"),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 1),

                  if (isApiModel) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: const [
                        Text(
                          "รายละเอียดผู้จัดส่ง",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: "Poppins",
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 🧭 เรียงรูป picture_status2 และ picture_status3 เป็น Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✅ รูปซ้าย (picture_status2)
                        Column(
                          children: [
                            pic2 != null
                                ? _b64ImageBox(pic2, w: 120, h: 120)
                                : _placeholderBox(w: 120, h: 120),
                            const SizedBox(height: 4),
                            const Text(
                              "รูปตอนรับของ",
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: "Poppins",
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(width: 12),

                        // ✅ รูปขวา (picture_status3 — เอาแค่รูปแรก ถ้ามีหลายรูป)
                        Column(
                          children: [
                            (pics3.isNotEmpty)
                                ? _b64ImageBox(pics3.first, w: 120, h: 120)
                                : _placeholderBox(w: 120, h: 120),
                            const SizedBox(height: 4),
                            const Text(
                              "รูปตอนส่งของเสร็จสิ้น",
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: "Poppins",
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
