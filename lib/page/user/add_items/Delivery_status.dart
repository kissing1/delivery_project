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
  final s = (item is Map)
      ? (item["status"] ?? "").toString()
      : (item.status ?? "").toString();
  return s.toLowerCase().trim();
}

bool _isFinished(dynamic item) {
  final s = _statusOf(item);
  return s == "finish" || s == "finished" || s == "done" || s == "completed";
}

/// ====== Theme สีที่ใช้ซ้ำ ======
const _kGreen = Color(0xFF32BD6C);
const _kGreenDark = Color(0xFF249B58);
const _kLeaf = Color(0xFF9EE0B7);
const _kPink = Color(0xFFFF5C8A);
const _kBg = Color(0xFFF6FAF8);

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
      backgroundColor: _kBg,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kGreen, _kGreenDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                labelPadding: const EdgeInsets.symmetric(vertical: 10),
                splashFactory: NoSplash.splashFactory,
                dividerHeight: 0,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                labelColor: _kGreenDark,
                unselectedLabelColor: Colors.white,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(
                  fontFamily: "Poppins",
                  fontWeight: FontWeight.w700,
                ),
                tabs: const [
                  Tab(text: "ทั้งหมด"),
                  Tab(text: "รอผู้ส่ง"),
                  Tab(text: "กำลังขนส่ง"),
                  Tab(text: "ขนส่งเสร็จสิ้น"),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AllWidget(apiBase: _apiBase!),
          WaitingWidget(userid: widget.userid),
          Consumer<DeliveryProvider>(
            builder: (_, p, __) =>
                ShippingWidget(deliveries: p.deliveries, userid: widget.userid),
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
/// 🟢 Widget “ทั้งหมด”
class AllWidget extends StatelessWidget {
  final String apiBase;
  const AllWidget({super.key, required this.apiBase});

  @override
  Widget build(BuildContext context) {
    final deliveries = context.watch<DeliveryProvider>().deliveries;

    if (deliveries.isEmpty) {
      return _emptyState("ยังไม่มีสินค้าที่จะส่ง");
    }

    return ListView.builder(
      key: const PageStorageKey<String>('all-list'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      itemCount: deliveries.length + 1,
      itemBuilder: (context, index) {
        if (index == deliveries.length) {
          return _confirmAllButton(context, deliveries);
        }
        final d = deliveries[index];
        return _animatedCard(index: index, child: _deliveryCard(context, d));
      },
    );
  }

  Widget _confirmAllButton(BuildContext context, List deliveries) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_outline, color: Colors.white),
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
            backgroundColor: _kPink,
            minimumSize: const Size(200, 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 4,
            shadowColor: _kPink.withOpacity(.35),
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

  Widget _deliveryCard(BuildContext context, dynamic d) {
    final provider = context.read<DeliveryProvider>();
    final index = provider.deliveries.indexOf(d);

    return Stack(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
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
          child: AnimatedScale(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            scale: 1.0,
            child: Card(
              color: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0x1A000000)),
              ),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (d.pictureProduct.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          const Base64Decoder().convert(d.pictureProduct),
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      )
                    else
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: _kLeaf.withOpacity(.35),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.inventory, color: _kGreen),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.nameProduct,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              fontFamily: "Poppins",
                            ),
                          ),
                          const SizedBox(height: 4),
                          _infoRow("จำนวน", "${d.amount}"),
                          _infoRow("ผู้รับ", d.receiverName ?? "-"),
                          _infoRow(
                            "ที่อยู่",
                            d.receiverAddress ?? "-",
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
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
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.delete, color: Colors.red),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// 🟡 Widget “รอผู้ส่ง”
class WaitingWidget extends StatefulWidget {
  final int userid;
  const WaitingWidget({super.key, required this.userid});

  @override
  State<WaitingWidget> createState() => _WaitingWidgetState();
}

class _WaitingWidgetState extends State<WaitingWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String? _apiBase;
  List<dynamic> _userDeliveries = [];
  bool _isLoading = true;
  bool _isFetching = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadConfigAndFetch();
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
        if (res.body.isEmpty || res.body == 'null') {
          if (mounted) {
            setState(() {
              _userDeliveries = [];
              _isLoading = false;
            });
          }
          return;
        }

        final decoded = jsonDecode(res.body);
        if (decoded is! Map<String, dynamic>) return;

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
      }
    } catch (e) {
      debugPrint("❌ Exception: $e");
    } finally {
      _isFetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _userDeliveries.where((e) {
      final s = _statusOf(e);
      return s != "transporting" &&
          s != "finish" &&
          s != "finished" &&
          s != "done" &&
          s != "completed";
    }).toList();

    if (filtered.isEmpty) {
      return _emptyState("ยังไม่มีรายการรอผู้ส่ง");
    }

    return RefreshIndicator(
      onRefresh: _fetchDeliveriesByUser,
      child: ListView.builder(
        key: const PageStorageKey<String>('waiting-list'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final d = filtered[index];
          final status = _statusOf(d);

          return _animatedCard(
            index: index,
            child: Card(
              color: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0x1A000000)),
              ),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                leading: _leadImage((d["picture_product"] ?? "").toString()),
                title: Text(
                  "ชื่อสินค้า: ${(d["name_product"] ?? "ไม่ทราบชื่อสินค้า")}",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    fontFamily: "Poppins",
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    _statusChip(status),
                    if (d["amount"] != null) Text("จำนวน: ${d["amount"]}"),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _leadImage(String rawB64) {
    final b64 = rawB64.replaceAll(RegExp(r'^data:image/[^;]+;base64,'), '');
    if (b64.trim().isEmpty) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: _kLeaf.withOpacity(.35),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.inventory, color: _kGreen),
      );
    }
    try {
      final bytes = const Base64Decoder().convert(b64);
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          bytes,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    } catch (_) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: _kLeaf.withOpacity(.35),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.error_outline, color: Colors.redAccent),
      );
    }
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// 🟠 Widget “กำลังขนส่ง”
class ShippingWidget extends StatefulWidget {
  final List deliveries; // จาก Provider (อาจเป็น model หรือ Map)
  final int? userid;

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
  String _lastJson = "";
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initApiBaseAndMaybeFetch();
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
          return;
        }

        if (mounted) {
          setState(() {
            _apiTransporting = onlyTransporting;
            _lastJson = newJson;
          });
        }
      }
    } catch (e) {
      debugPrint("❌ list-by-user exception: $e");
    } finally {
      _loading = false;
    }
  }

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
      return _emptyState("ยังไม่มีรายการกำลังขนส่ง");
    }

    return RefreshIndicator(
      onRefresh: _fetchTransportingFromApi,
      child: ListView.builder(
        key: const PageStorageKey<String>('shipping-list'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        itemCount: combined.length,
        itemBuilder: (context, index) {
          final d = combined[index];
          final isApiModel = d is senderlist.Delivery;

          final name = _nameOf(d);
          final status = _statusOfAny(d);
          final amount = _amountOf(d);
          final prodB64 = _pictureProductB64(d);
          final hasProdPic = prodB64.isNotEmpty;

          return _animatedCard(
            index: index,
            child: GestureDetector(
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
                color: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0x1A000000)),
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
                              : Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: _kLeaf.withOpacity(.35),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.local_shipping,
                                    color: _kGreen,
                                  ),
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
                                    fontWeight: FontWeight.w800,
                                    fontFamily: "Poppins",
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _statusChip(status),
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
  final int? userid;

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
  List<senderlist.Delivery> _apiDone = [];

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
          if (mounted) setState(() => _apiDone = []);
          return;
        }
        final parsed = senderlist.byListSenderGetResFromJson(res.body);
        final onlyDone = parsed.deliveries
            .where((d) => _isFinishedStr(d.status))
            .toList();
        if (mounted) setState(() => _apiDone = onlyDone);
      }
    } catch (e) {
      debugPrint("❌ list-by-user exception: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
      return _emptyState("ยังไม่มีรายการขนส่งเสร็จสิ้น");
    }

    return RefreshIndicator(
      onRefresh: _fetchDoneFromApi,
      child: ListView.builder(
        key: const PageStorageKey<String>('done-list'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
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

          return _animatedCard(
            index: index,
            child: Card(
              color: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0x1A000000)),
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
                            : Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: _kLeaf.withOpacity(.35),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  color: Colors.blue,
                                ),
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
                                  fontWeight: FontWeight.w800,
                                  fontFamily: "Poppins",
                                ),
                              ),
                              const SizedBox(height: 4),
                              _statusChip("$status ✅"),
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
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
            ),
          );
        },
      ),
    );
  }
}

/// =====================
/// Widgets/Helpers ร่วม
/// =====================
Widget _animatedCard({required int index, required Widget child}) {
  final ms = 240 + (index * 50).clamp(0, 400);
  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: ms),
    curve: Curves.easeOutCubic,
    builder: (context, v, _) => Opacity(
      opacity: v,
      child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child),
    ),
  );
}

Widget _statusChip(String status) {
  final s = status.toLowerCase();
  Color bg = _kLeaf.withOpacity(.25);
  Color fg = _kGreenDark;
  if (s.contains("transport")) {
    bg = const Color(0xFFCCE8FF);
    fg = const Color(0xFF0B74DA);
  } else if (s.contains("accept") || s.contains("รอ")) {
    bg = const Color(0xFFFFF3CD);
    fg = const Color(0xFF8A6D3B);
  } else if (s.contains("finish") ||
      s.contains("done") ||
      s.contains("completed") ||
      s.contains("เสร็จ")) {
    bg = const Color(0xFFD4EDDA);
    fg = const Color(0xFF2E7D32);
  }
  return AnimatedContainer(
    duration: const Duration(milliseconds: 250),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: fg.withOpacity(.35)),
    ),
    child: Text(
      status,
      style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12.5),
    ),
  );
}

Widget _emptyState(String text) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _kLeaf.withOpacity(.4),
        ),
        child: const Icon(Icons.local_shipping, color: _kGreen, size: 40),
      ),
      const SizedBox(height: 12),
      Text(
        text,
        style: const TextStyle(
          fontFamily: "Poppins",
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        "ดึงเพื่อรีเฟรชหรือลองใหม่อีกครั้ง",
        style: TextStyle(color: Colors.black54),
      ),
    ],
  );
}
