import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/config/config.dart';
import 'package:flutter_application_1/model/responses/users_id_get_res.dart';
import 'package:flutter_application_1/page/user/add_items/location_rider.dart';

class SenderDetail extends StatefulWidget {
  /// รับค่ามาจากหน้าก่อนหน้า
  final int deliveryId;
  final int userId;
  final int? riderId;

  const SenderDetail({
    super.key,
    required this.deliveryId,
    required this.userId,
    required this.riderId,
  });

  @override
  State<SenderDetail> createState() => _SenderDetailState();
}

class _SenderDetailState extends State<SenderDetail> {
  UsersIdGetRes? _rider;
  bool _loading = true;
  String? _error; // เก็บข้อความ error (ถ้ามี)

  @override
  void initState() {
    super.initState();
    _fetchRiderDetail();
  }

  Future<void> _fetchRiderDetail() async {
    // ถ้าไม่มี riderId ก็ไม่ต้องยิง API
    if (widget.riderId == null) {
      setState(() {
        _loading = false;
        _error = 'ยังไม่พบข้อมูลไรเดอร์ของงานนี้';
      });
      return;
    }

    try {
      final cfg = await Configuration.getConfig();
      final baseUrl = cfg["apiEndpoint"];
      final url = Uri.parse("$baseUrl/users/${widget.riderId}");
      debugPrint(
        "🔎 GET $url (deliveryId=${widget.deliveryId}, userId=${widget.userId})",
      );

      final res = await http.get(url);

      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = usersIdGetResFromJson(res.body);
        setState(() {
          _rider = data;
          _loading = false;
        });
      } else {
        debugPrint(
          "❌ GET /users/${widget.riderId} failed: ${res.statusCode} ${res.body}",
        );
        setState(() {
          _loading = false;
          _error = 'ดึงข้อมูลไรเดอร์ไม่สำเร็จ (${res.statusCode})';
        });
      }
    } catch (e) {
      debugPrint("❌ Exception while fetch rider: $e");
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'เกิดข้อผิดพลาด: $e';
      });
    }
  }

  ImageProvider _avatarFromBase64(String? data) {
    if (data == null || data.isEmpty) {
      return const AssetImage('assets/images/profile_placeholder.png');
    }
    try {
      final cleaned = data.replaceAll(RegExp(r'^data:image/[^;]+;base64,'), '');
      return MemoryImage(base64Decode(cleaned));
    } catch (_) {
      return const AssetImage('assets/images/profile_placeholder.png');
    }
  }

  @override
  Widget build(BuildContext context) {
    // สถานะโหลด
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // กรณีไม่มีข้อมูลหรือ error
    if (_rider == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("รายละเอียดผู้จัดส่ง"),
          backgroundColor: Colors.green,
          centerTitle: true,
        ),
        body: Center(child: Text(_error ?? "ไม่พบข้อมูลไรเดอร์")),
      );
    }

    // มีข้อมูลพร้อมแสดง
    return Scaffold(
      appBar: AppBar(
        title: const Text("รายละเอียดผู้จัดส่ง"),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // โลโก้ตำแหน่ง
            Image.asset("assets/images/img_5.png", width: 100),
            const SizedBox(height: 10),
            const Text(
              "ตำแหน่งของ ไรเดอร์",
              style: TextStyle(
                fontFamily: "Poppins",
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),

            // หัวข้อ
            Row(
              children: const [
                Text(
                  "รายละเอียดของผู้จัดส่ง",
                  style: TextStyle(
                    fontFamily: "Poppins",
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
            const SizedBox(height: 10),

            // การ์ดโปรไฟล์ไรเดอร์
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundImage: _avatarFromBase64(_rider!.picture),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kvText("ผู้จัดส่ง:", _rider!.name),
                        const SizedBox(height: 6),
                        _kvText("เบอร์โทร:", _rider!.phone),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ปุ่มดูตำแหน่งไรเดอร์
            ElevatedButton.icon(
              icon: const Icon(Icons.location_on),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              label: const Text(
                "ดูตำแหน่งไรเดอร์",
                style: TextStyle(fontFamily: "Poppins", fontSize: 16),
              ),
              onPressed: () {
                if (widget.riderId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LocationRider(riderId: widget.riderId!),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("ไม่มี Rider ID")),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// แถวแสดง Key-Value สั้น ๆ
  Widget _kvText(String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$k ",
          style: const TextStyle(
            fontFamily: "Poppins",
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(fontFamily: "Poppins"),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
