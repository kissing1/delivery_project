import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/page/user/add_items/location_rider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/model/responses/users_id_get_res.dart';
import 'package:flutter_application_1/config/config.dart';

class RiderDetail extends StatefulWidget {
  final int? riderId;
  final int deliveryId;
  final int? userid;

  const RiderDetail({
    super.key,
    required this.riderId,
    required this.deliveryId,
    this.userid,
  });

  @override
  State<RiderDetail> createState() => _RiderDetailState();
}

class _RiderDetailState extends State<RiderDetail> {
  UsersIdGetRes? _rider;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchRiderDetail();
  }

  Future<void> _fetchRiderDetail() async {
    try {
      final cfg = await Configuration.getConfig();
      final baseUrl = cfg["apiEndpoint"];
      final url = Uri.parse("$baseUrl/users/${widget.riderId}");

      final res = await http.get(url);

      if (res.statusCode == 200) {
        final data = usersIdGetResFromJson(res.body);
        setState(() {
          _rider = data;
          _loading = false;
        });
      } else {
        debugPrint("❌ GET /users/${widget.riderId} failed: ${res.body}");
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint("❌ Exception: $e");
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_rider == null) {
      return const Scaffold(body: Center(child: Text("ไม่พบข้อมูลไรเดอร์")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("รายละเอียดไรเดอร์"),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 🧭 โลโก้ตำแหน่ง
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

            const Text(
              "รายละเอียดของผู้จัดส่ง",
              style: TextStyle(
                fontFamily: "Poppins",
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // 🧑 การ์ดโปรไฟล์ไรเดอร์
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
                    backgroundImage: _rider!.picture.isNotEmpty
                        ? MemoryImage(
                            base64Decode(
                              _rider!.picture.replaceAll(
                                RegExp(r'^data:image/[^;]+;base64,'),
                                '',
                              ),
                            ),
                          )
                        : const AssetImage(
                                'assets/images/profile_placeholder.png',
                              )
                              as ImageProvider,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "ผู้จัดส่ง: ",
                              style: TextStyle(
                                fontFamily: "Poppins",
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _rider!.name,
                                style: const TextStyle(
                                  fontFamily: "Poppins",
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Text(
                              "เบอร์โทร: ",
                              style: TextStyle(
                                fontFamily: "Poppins",
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _rider!.phone,
                              style: const TextStyle(
                                fontFamily: "Poppins",
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 📍 ปุ่มไปหน้า LocationRider
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
}
