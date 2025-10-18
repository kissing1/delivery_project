import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/config/config.dart';
import 'package:flutter_application_1/model/responses/users_id_get_res.dart';
import 'package:flutter_application_1/model/responses/users_address_id_get_res.dart';
import 'package:http/http.dart' as http;

class DeliveryDetailPage extends StatefulWidget {
  final Map<String, dynamic> deliveryData;

  const DeliveryDetailPage({
    super.key,
    required this.deliveryData,
    required deliveryId, // ✅ คงพารามิเตอร์เดิมไว้ ไม่แตะระบบอื่น
  });

  @override
  State<DeliveryDetailPage> createState() => _DeliveryDetailPageState();
}

class _DeliveryDetailPageState extends State<DeliveryDetailPage>
    with SingleTickerProviderStateMixin {
  String? _apiBase;
  String receiverName = "-";
  String receiverAddress = "-";
  String coordinate = "-";
  bool _isLoading = true;

  // ----- THEME -----
  static const _kGreen = Color(0xFF32BD6C);
  static const _kGreenDark = Color(0xFF249B58);
  static const _kLeaf = Color(0xFF9EE0B7);
  static const _kBg = Color(0xFFF6FAF8);

  late final AnimationController _ctrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeIn = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, .06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _loadConfigAndFetchData();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ✅ โหลดค่า config และ fetch ข้อมูลผู้รับ
  Future<void> _loadConfigAndFetchData() async {
    try {
      final cfg = await Configuration.getConfig();
      _apiBase = (cfg['apiEndpoint'] as String?)?.trim();

      if ((_apiBase ?? '').isNotEmpty) {
        await _fetchReceiverDetails();
      }
    } catch (e) {
      debugPrint("⚠️ โหลด config หรือข้อมูลไม่ได้: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _ctrl.forward(); // เริ่มเล่นแอนิเมชันเข้า
      }
    }
  }

  // ✅ ดึงข้อมูลผู้รับและที่อยู่จาก API
  Future<void> _fetchReceiverDetails() async {
    final userId = widget.deliveryData["user_id_receiver"];
    final addressId = widget.deliveryData["address_id_receiver"];

    try {
      final resUser = await http.get(Uri.parse("$_apiBase/users/$userId"));
      if (resUser.statusCode == 200) {
        final userData = usersIdGetResFromJson(resUser.body);
        receiverName = userData.name.isNotEmpty ? userData.name : "-";
      }

      final resAddr = await http.get(
        Uri.parse("$_apiBase/users/address/$addressId"),
      );
      if (resAddr.statusCode == 200) {
        final addrData = usersAddressIdGetResFromJson(resAddr.body);
        receiverAddress = addrData.address.isNotEmpty ? addrData.address : "-";
        coordinate = "${addrData.lat}, ${addrData.lng}";
      }
    } catch (e) {
      debugPrint("⚠️ fetch receiver failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageBase64 = (widget.deliveryData['picture_product'] ?? '')
        .toString();
    final name = (widget.deliveryData['name_product'] ?? '-').toString();
    final status = (widget.deliveryData['status'] ?? '-').toString();
    final amount = (widget.deliveryData['amount'] ?? '-').toString();
    final detail = (widget.deliveryData['detail_product'] ?? '-').toString();

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
          "รายละเอียดของสินค้า",
          style: TextStyle(
            fontFamily: "Poppins",
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'รีโหลด',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () async {
              setState(() => _isLoading = true);
              await _fetchReceiverDetails();
              if (mounted) setState(() => _isLoading = false);
              _ctrl
                ..reset()
                ..forward();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // -------- Content --------
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    key: const ValueKey('loaded'),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    child: FadeTransition(
                      opacity: _fadeIn,
                      child: SlideTransition(
                        position: _slideUp,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ชื่อสินค้า + สถานะ
                            _headerTitle(name, status),
                            const SizedBox(height: 12),

                            // การ์ดรูปสินค้า
                            _productImageCard(imageBase64, name),

                            const SizedBox(height: 12),

                            // การ์ดรายละเอียด
                            _detailCard(detail: detail, amount: amount),

                            const SizedBox(height: 12),

                            // การ์ดข้อมูลผู้รับ
                            _receiverCard(
                              receiverName: receiverName,
                              receiverAddress: receiverAddress,
                              coordinate: coordinate,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),

          // -------- Footer (ถนน + รถ) พร้อม animation เล็กน้อย --------
          Positioned(left: 0, right: 0, bottom: 0, child: _footerRoad()),
        ],
      ),
    );
  }

  // ---------- UI parts ----------
  Widget _headerTitle(String name, String status) {
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              fontFamily: "Poppins",
              color: Colors.black87,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _statusChip(status),
      ],
    );
  }

  // ===== (แทนที่) การ์ดรูปสินค้า — แสดงภาพเต็มรูปแบบไม่ครอป =====
  Widget _productImageCard(String b64, String name) {
    final clean = b64
        .replaceAll(RegExp(r'^data:image/[^;]+;base64,'), '')
        .trim();

    // กรอบว่างกรณีไม่มีรูป
    Widget _placeholder({double h = 280}) => Container(
      height: h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kLeaf.withOpacity(.25),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported, color: _kGreen, size: 50),
    );

    Widget content;
    if (clean.isEmpty) {
      content = _placeholder();
    } else {
      try {
        final bytes = const Base64Decoder().convert(clean);

        // ดึงขนาดภาพเพื่อคุม AspectRatio (จะได้ไม่เพี้ยน/ไม่ครอป)
        final img = Image.memory(bytes);
        content = FutureBuilder<ImageInfo>(
          future: _getImageInfo(img.image),
          builder: (context, snap) {
            if (!snap.hasData) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _placeholder(h: 220),
              );
            }
            final w = snap.data!.image.width.toDouble();
            final h = snap.data!.image.height.toDouble();
            final ratio = (w == 0 || h == 0) ? 16 / 9 : w / h;

            return ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                builder: (context, v, child) => Opacity(
                  opacity: v,
                  child: Transform.scale(scale: .98 + (v * .02), child: child),
                ),
                child: Container(
                  color: Colors.white, // ฉากหลังรองรับ contain
                  child: AspectRatio(
                    aspectRatio: ratio,
                    child: GestureDetector(
                      onTap: () => _openFullImage(bytes),
                      child: FittedBox(
                        fit: BoxFit.contain, // ✅ แสดงครบทั้งภาพ
                        child: Image.memory(bytes, gaplessPlayback: true),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      } catch (_) {
        content = _placeholder();
      }
    }

    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0x1A000000)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            content,
            const SizedBox(height: 10),
            Row(
              children: const [
                Icon(Icons.inventory_2_outlined, color: _kGreen),
                SizedBox(width: 8),
                Text(
                  "รูปสินค้า (แตะเพื่อขยาย)",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontFamily: "Poppins",
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ดึง ImageInfo เพื่อหาขนาดภาพจริง
  Future<ImageInfo> _getImageInfo(ImageProvider provider) async {
    final c = Completer<ImageInfo>();
    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        c.complete(info);
        stream.removeListener(listener);
      },
      onError: (e, st) {
        if (!c.isCompleted) c.completeError(e, st);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return c.future;
  }

  // ===== (ใหม่) เปิดภาพเต็มจอแบบซูมได้ =====
  void _openFullImage(Uint8List bytes) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(.85),
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Dismissible(
          key: const Key('full-image'),
          direction: DismissDirection.down,
          onDismissed: (_) => Navigator.pop(context),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: Hero(
                      tag: bytes.hashCode, // tag แบบง่ายๆ กันกระพริบ
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 5,
                        panEnabled: true,
                        child: Image.memory(bytes, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                      tooltip: 'ปิด',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailCard({required String detail, required String amount}) {
    return _cardShell(
      titleIcon: Icons.description_outlined,
      title: "รายละเอียดสินค้า",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rowLabelValue("รายละเอียด", detail, maxLines: 6),
          const SizedBox(height: 6),
          _rowLabelValue("จำนวน", amount, bold: true),
        ],
      ),
    );
  }

  Widget _receiverCard({
    required String receiverName,
    required String receiverAddress,
    required String coordinate,
  }) {
    return _cardShell(
      titleIcon: Icons.person_pin_circle_outlined,
      title: "ข้อมูลผู้รับ",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rowLabelValue("ผู้รับ", receiverName, bold: true),
          _rowLabelValue("ที่อยู่", receiverAddress, maxLines: 4),
          _rowLabelValue("พิกัด", coordinate),
        ],
      ),
    );
  }

  Widget _cardShell({
    required IconData titleIcon,
    required String title,
    required Widget child,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - v)),
          child: Card(
            elevation: 3,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0x1A000000)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(titleIcon, color: _kGreen),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: "Poppins",
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ แถวข้อความสวย ๆ
  Widget _rowLabelValue(
    String label,
    String value, {
    bool bold = false,
    int maxLines = 3,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
          const SizedBox(width: 8),
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

  // ✅ Status chip with animation
  Widget _statusChip(String status) {
    final s = status.toLowerCase();
    Color bg = _kLeaf.withOpacity(.25);
    Color fg = _kGreenDark;

    if (s.contains("transport")) {
      bg = const Color(0xFFCCE8FF);
      fg = const Color(0xFF0B74DA);
    } else if (s.contains("finish") ||
        s.contains("done") ||
        s.contains("completed") ||
        s.contains("เสร็จ")) {
      bg = const Color(0xFFD4EDDA);
      fg = const Color(0xFF2E7D32);
    } else if (s.contains("accept") || s.contains("รอ")) {
      bg = const Color(0xFFFFF3CD);
      fg = const Color(0xFF8A6D3B);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: fg.withOpacity(.35)),
        ),
        child: Text(
          status,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  // ✅ Footer ถนน + รถ พร้อมเด้งนิดๆ
  Widget _footerRoad() {
    return SizedBox(
      height: 92,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Image.asset(
              "assets/images/img_8_cropped.png",
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            bottom: 6,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.94, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              builder: (context, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Image.asset(
                // ใช้รูปเดิมของคุณ ถ้าไม่มี delivery_scooter.png ให้ชี้ไป img_1_cropped.png
                "assets/images/delivery_scooter.png",
                width: 150,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
