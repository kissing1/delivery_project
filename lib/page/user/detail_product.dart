import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/config/config.dart';
import 'package:flutter_application_1/model/responses/detail_delivery_get_res.dart';
import 'package:flutter_application_1/model/responses/users_id_get_res.dart';

class DetailProduct extends StatefulWidget {
  final int deliveryId;
  final int userid;

  const DetailProduct({
    super.key,
    required this.deliveryId,
    required this.userid,
  });

  @override
  State<DetailProduct> createState() => _DetailProductState();
}

class _DetailProductState extends State<DetailProduct>
    with SingleTickerProviderStateMixin {
  DetailDeliveryGetRes? _detail;
  UsersIdGetRes? _sender;
  bool _loading = true;
  String? _apiBase;

  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    Configuration.getConfig().then((cfg) {
      setState(() => _apiBase = (cfg['apiEndpoint'] as String?)?.trim());
      _fetchDetail();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchDetail() async {
    if (_apiBase == null) return;
    try {
      final url = Uri.parse("$_apiBase/delivery/${widget.deliveryId}");
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = detailDeliveryGetResFromJson(res.body);
        setState(() {
          _detail = data;
          _loading = false;
        });
        _fetchSender(data.userIdSender);
        _controller.forward(); // 🟢 เริ่ม animation หลังโหลดเสร็จ
      } else {
        debugPrint("❌ API Error ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Fetch detail error: $e");
    }
  }

  Future<void> _fetchSender(int senderId) async {
    if (_apiBase == null) return;
    try {
      final url = Uri.parse("$_apiBase/users/$senderId");
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = usersIdGetResFromJson(res.body);
        setState(() {
          _sender = data;
        });
      }
    } catch (e) {
      debugPrint("❌ fetch sender error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFEFFBF2),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF2ECC71)),
              SizedBox(height: 12),
              Text(
                "กำลังโหลดข้อมูลสินค้า...",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_detail == null) {
      return const Scaffold(body: Center(child: Text("ไม่พบข้อมูลสินค้า ❌")));
    }

    // ✅ แปลง base64 เป็นรูป
    ImageProvider imageProvider;
    if (_detail!.pictureProduct.isNotEmpty) {
      try {
        final cleaned = _detail!.pictureProduct.replaceAll(
          RegExp(r'^data:image/[^;]+;base64,'),
          '',
        );
        imageProvider = MemoryImage(base64Decode(cleaned));
      } catch (_) {
        imageProvider = const AssetImage("assets/images/placeholder.png");
      }
    } else {
      imageProvider = const AssetImage("assets/images/placeholder.png");
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEFFBF2), // พื้นหลังเขียวอ่อน
      appBar: AppBar(
        title: const Text("รายละเอียดของสินค้า"),
        backgroundColor: const Color(0xFF2ECC71),
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 6,
              shadowColor: Colors.green.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Hero(
                        tag: "product_${_detail!.deliveryId}",
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image(
                            image: imageProvider,
                            width: 150,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildRow("ชื่อสินค้า:", _detail!.nameProduct),
                    const SizedBox(height: 10),
                    _buildRow("รายละเอียด:", _detail!.detailProduct),
                    const SizedBox(height: 10),
                    _buildStatusChip(_detail!.status),
                    const SizedBox(height: 10),
                    _buildRow("ผู้ส่ง:", _sender?.name ?? "กำลังโหลด..."),
                    const SizedBox(height: 10),
                    _buildRow("ที่อยู่:", _detail!.addressReceiver.address),
                    const SizedBox(height: 10),
                    _buildRow(
                      "พิกัด:",
                      "${_detail!.addressReceiver.lat}, ${_detail!.addressReceiver.lng}",
                    ),
                    const SizedBox(height: 10),
                    _buildRow("จำนวนพัสดุ:", "${_detail!.amount} ชิ้น"),
                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2ECC71),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 24,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        label: const Text(
                          "ย้อนกลับ",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 15, color: Colors.black54),
          ),
        ),
      ],
    );
  }

  /// ✅ สร้าง status chip
  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'waiting':
        color = Colors.orange;
        break;
      case 'delivering':
        color = Colors.blue;
        break;
      case 'finish':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Row(
      children: [
        const Text("สถานะ:", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 10),
        Chip(
          backgroundColor: color.withOpacity(0.2),
          avatar: Icon(Icons.local_shipping, color: color),
          label: Text(
            status.toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
