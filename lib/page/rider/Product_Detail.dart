import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/config/config.dart';
import 'package:flutter_application_1/model/responses/detail_delivery_get_res.dart';
import 'package:flutter_application_1/model/responses/users_id_get_res.dart';

class ProductDetail extends StatefulWidget {
  final int deliveryId; // ต้องมีเสมอ
  final int? riderId; // ไม่บังคับ

  const ProductDetail({super.key, required this.deliveryId, this.riderId});

  @override
  State<ProductDetail> createState() => _ProductDetailState();
}

class _ProductDetailState extends State<ProductDetail> {
  DetailDeliveryGetRes? _detail;
  String? _receiverName; // ชื่อผู้รับจาก /users/{id}
  bool _loading = true;
  bool _loadingReceiver = false;
  String? _apiBase;

  // ===== THEME (delivery premium) =====
  static const _kBg = Color(0xFFF6FAF8);
  static const _kGreen = Color(0xFF32BD6C);
  static const _kGreenDark = Color(0xFF249B58);
  static const _kInk = Color(0xFF101214);
  static const _kPink = Color(0xFFFF5C8A);

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text('โหลดการตั้งค่าไม่สำเร็จ: $e'),
        ),
      );
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
        // ได้ detail แล้ว → ยิงหาชื่อผู้รับ
        _fetchReceiverName(data.userIdReceiver);
      } else {
        debugPrint('❌ ${res.statusCode} ${res.body}');
        if (!mounted) return;
        setState(() => _loading = false);
        _toastError('โหลดข้อมูลไม่สำเร็จ: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ fetch detail exception: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      _toastError('เกิดข้อผิดพลาด: $e');
    }
  }

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

  // ===== Helpers (UI only) =====

  void _toastError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(msg),
      ),
    );
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
            width: 90,
            child: Text(
              "$label:",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black.withOpacity(.66),
                letterSpacing: .2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: _kInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String text,
    Color color = _kGreen,
    Color? fg,
  }) {
    final fgColor = fg ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.darken(.14)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 6),
            color: color.withOpacity(.28),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fgColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: fgColor,
              fontWeight: FontWeight.w800,
              letterSpacing: .3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 15,
        color: _kInk,
        fontWeight: FontWeight.w900,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: AppBar(
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_kGreen, _kGreenDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
          title: Column(
            children: const [
              Text(
                "รายละเอียดของสินค้า",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .2,
                ),
              ),
              SizedBox(height: 2),
              Text(
                "Delivery • Premium",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .4,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: "รีเฟรช",
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _fetchDetail,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_detail == null
                ? const Center(child: Text('ไม่พบข้อมูล'))
                : RefreshIndicator(
                    onRefresh: _fetchDetail,
                    edgeOffset: 80,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                      children: [
                        // ===== Top meta row: หมายเลขงาน + ไรเดอร์ =====
                        Row(
                          children: [
                            _chip(
                              icon: Icons.receipt_long_rounded,
                              text: "ID: ${widget.deliveryId}",
                            ),
                            const SizedBox(width: 8),
                            if (widget.riderId != null)
                              _chip(
                                icon: Icons.delivery_dining,
                                text: "Rider: ${widget.riderId}",
                                color: _kPink,
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // ===== Product Card =====
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 18,
                                spreadRadius: 1,
                                offset: const Offset(0, 10),
                                color: Colors.black.withOpacity(.08),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.black12.withOpacity(.06),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // รูปสินค้า + ป้ายประเภท
                                Row(
                                  children: [
                                    Container(
                                      width: 110,
                                      height: 110,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F6F3),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.black12.withOpacity(
                                            .08,
                                          ),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            blurRadius: 10,
                                            offset: const Offset(0, 6),
                                            color: Colors.black.withOpacity(
                                              .06,
                                            ),
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
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _sectionTitle("ข้อมูลสินค้า"),
                                          Text(
                                            _detail!.nameProduct,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: _kInk,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.inventory_2_rounded,
                                                size: 16,
                                                color: _kGreenDark,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                "จำนวน: ${_detail!.amount}",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _rowLabelValue(
                                  "รายละเอียด",
                                  _detail!.detailProduct,
                                  maxLines: 6,
                                ),
                                const SizedBox(height: 6),
                                Divider(color: Colors.black12.withOpacity(.10)),

                                // ===== Receiver section =====
                                const SizedBox(height: 6),
                                _sectionTitle("ข้อมูลผู้รับ"),
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

                        const SizedBox(height: 14),

                        // ===== Status row (premium chip) =====
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.black12.withOpacity(.08),
                            ),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 16,
                                offset: const Offset(0, 10),
                                color: Colors.black.withOpacity(.06),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _kGreen.withOpacity(.10),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.local_shipping_rounded,
                                  color: _kGreenDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "สถานะปัจจุบัน",
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _kInk,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [_kGreen, _kGreenDark],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                      blurRadius: 10,
                                      offset: const Offset(0, 6),
                                      color: _kGreenDark.withOpacity(.25),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _detail!.status,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        // ===== Small footnote =====
                      ],
                    ),
                  )),
    );
  }
}

/// สีเข้มขึ้นเล็กน้อย (สำหรับเงา/กราเดียนต์)
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
