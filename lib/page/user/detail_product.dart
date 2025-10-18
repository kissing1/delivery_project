// lib/page/user/detail_product.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/config/config.dart';
import 'package:flutter_application_1/model/responses/detail_delivery_get_res.dart';
import 'package:flutter_application_1/model/responses/users_id_get_res.dart';

class DetailProduct extends StatefulWidget {
  final int deliveryId;
  final int
  userid; // คงพารามิเตอร์ตามของเดิม (ไม่ได้ใช้งานในหน้านี้ แต่คงไว้ไม่ให้พัง)

  const DetailProduct({
    super.key,
    required this.deliveryId,
    required this.userid,
  });

  @override
  State<DetailProduct> createState() => _DetailProductState();
}

class _DetailProductState extends State<DetailProduct> {
  DetailDeliveryGetRes? _detail;
  String? _receiverName; // ✅ ชื่อผู้รับจาก /users/{id}
  bool _loading = true;
  bool _loadingReceiver = false;
  String? _apiBase;

  // ===== Delivery theme colors =====
  static const _kBg = Color(0xFFF6FAF8);
  static const _kGreen = Color(0xFF32BD6C);
  static const _kGreenDark = Color(0xFF249B58);
  static const _kInk = Color(0xFF111418);

  @override
  void initState() {
    super.initState();
    _loadConfigAndFetch();
  }

  Future<void> _loadConfigAndFetch() async {
    try {
      final cfg = await Configuration.getConfig();
      _apiBase = (cfg['apiEndpoint'] as String?)?.trim();
      await _fetchDetail();
    } catch (e) {
      debugPrint('❌ load config error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('โหลดการตั้งค่าไม่สำเร็จ: $e')));
    }
  }

  Future<void> _fetchDetail() async {
    if (_apiBase == null) return;
    setState(() => _loading = true);
    try {
      final url = Uri.parse("$_apiBase/delivery/${widget.deliveryId}");
      debugPrint('➡️ GET $url');
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final data = detailDeliveryGetResFromJson(res.body);
        if (!mounted) return;
        setState(() {
          _detail = data;
          _loading = false;
        });

        // ✅ ได้ detail แล้วค่อยยิงไปเอาชื่อผู้รับ
        _fetchReceiverName(data.userIdReceiver);
      } else {
        debugPrint('❌ ${res.statusCode} ${res.body}');
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดข้อมูลไม่สำเร็จ: ${res.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint('❌ fetch detail exception: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  /// ✅ ดึงชื่อผู้รับจาก /users/{userId}
  Future<void> _fetchReceiverName(int userId) async {
    if (_apiBase == null) return;
    setState(() => _loadingReceiver = true);
    try {
      final url = Uri.parse("$_apiBase/users/$userId");
      debugPrint('➡️ GET $url (receiver)');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final user = usersIdGetResFromJson(res.body);
        if (!mounted) return;
        setState(() {
          _receiverName = user.name;
          _loadingReceiver = false;
        });
      } else {
        debugPrint('❌ fetch receiver ${res.statusCode} ${res.body}');
        if (!mounted) return;
        setState(() => _loadingReceiver = false);
      }
    } catch (e) {
      debugPrint('❌ fetch receiver exception: $e');
      if (!mounted) return;
      setState(() => _loadingReceiver = false);
    }
  }

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
      debugPrint('❌ decode product image: $e');
    }
    return const AssetImage('assets/images/no_image.png');
  }

  Widget _rowLabelValue(
    String label,
    String value, {
    bool bold = false,
    int maxLines = 3,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: Colors.black87,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "รายละเอียดของสินค้า",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchDetail,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kGreen))
          : (_detail == null
                ? const Center(child: Text('ไม่พบข้อมูล'))
                : RefreshIndicator(
                    onRefresh: _fetchDetail,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // ===== การ์ดหลัก =====
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.black12.withOpacity(.08),
                            ),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 14,
                                color: Colors.black.withOpacity(.06),
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // รูปสินค้า
                                Center(
                                  child: Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.black12.withOpacity(.08),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          blurRadius: 10,
                                          color: Colors.black.withOpacity(.06),
                                        ),
                                      ],
                                      image: DecorationImage(
                                        image: _imgFrom(
                                          _detail!.pictureProduct,
                                        ),
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // ข้อมูลสินค้า
                                _rowLabelValue(
                                  "ชื่อ",
                                  _detail!.nameProduct,
                                  bold: true,
                                  maxLines: 2,
                                ),
                                _rowLabelValue(
                                  "รายละเอียด",
                                  _detail!.detailProduct,
                                  maxLines: 6,
                                ),
                                _rowLabelValue(
                                  "จำนวน",
                                  "${_detail!.amount}",
                                  bold: true,
                                ),
                                const SizedBox(height: 8),

                                Divider(
                                  color: Colors.black12.withOpacity(.2),
                                  thickness: 1,
                                  height: 24,
                                ),

                                // หัวข้อย่อย
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.inventory_2, color: _kGreenDark),
                                    SizedBox(width: 6),
                                    Text(
                                      "รายละเอียดการจัดส่ง",
                                      style: TextStyle(
                                        color: _kInk,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // ✅ ผู้รับ = ชื่อจาก /users/{id}
                                _rowLabelValue(
                                  "ผู้รับ",
                                  _loadingReceiver
                                      ? "กำลังโหลดชื่อผู้รับ..."
                                      : (_receiverName ?? "-"),
                                ),
                                _rowLabelValue(
                                  "ที่อยู่",
                                  _detail!.addressReceiver.address,
                                  maxLines: 4,
                                ),
                                _rowLabelValue(
                                  "พิกัด",
                                  "${_detail!.addressReceiver.lat}  ${_detail!.addressReceiver.lng}",
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ===== แถบสถานะปัจจุบัน =====
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 14,
                          ),
                          decoration: BoxDecoration(
                            color: _kGreen.withOpacity(.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _kGreen.withOpacity(.2)),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 10,
                                color: Colors.black.withOpacity(.05),
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.local_shipping_outlined,
                                color: _kGreenDark,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                "สถานะปัจจุบัน",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _kInk,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _kGreen.withOpacity(.6),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      blurRadius: 8,
                                      color: Colors.black.withOpacity(.06),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _detail!.status,
                                  style: TextStyle(
                                    color: _kGreen.darken(),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
    );
  }
}

/// สีเข้มขึ้นนิด ๆ สำหรับป้ายสถานะ
extension _ColorX on Color {
  Color darken([double amount = .12]) {
    assert(amount >= 0 && amount <= 1);
    final f = 1 - amount;
    return Color.fromARGB(
      alpha,
      (red * f).round(),
      (green * f).round(),
      (blue * f).round(),
    );
  }
}
