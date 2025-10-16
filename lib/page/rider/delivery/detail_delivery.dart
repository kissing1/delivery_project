import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/config/config.dart';
import 'package:flutter_application_1/model/responses/detail_delivery_get_res.dart';
import 'package:flutter_application_1/model/responses/users_id_get_res.dart';
import 'package:flutter_application_1/page/rider/delivery/Sender_address.dart';
import 'package:http/http.dart' as http;

class DetailDelivery extends StatefulWidget {
  final int deliveryId;
  final int riderId;

  const DetailDelivery({
    super.key,
    required this.deliveryId,
    required this.riderId,
  });

  @override
  State<DetailDelivery> createState() => _DetailDeliveryState();
}

class _DetailDeliveryState extends State<DetailDelivery> {
  String? _apiBase;
  DetailDeliveryGetRes? _deliveryDetail;
  UsersIdGetRes? getuserid;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Configuration.getConfig()
        .then((cfg) {
          setState(() => _apiBase = (cfg['apiEndpoint'] as String?)?.trim());
          fetchDetail(widget.deliveryId);
        })
        .catchError((e) {
          debugPrint("อ่าน config ไม่ได้: $e");
        });
  }

  Future<void> fetchDetail(int deliveryId) async {
    if (_apiBase == null) return;
    final url = Uri.parse("$_apiBase/delivery/$deliveryId");
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final data = detailDeliveryGetResFromJson(res.body);
      setState(() {
        _deliveryDetail = data;
        _loading = false;
      });
      useridreceiver(data.userIdReceiver);
    } else {
      print("โหลดข้อมูลไม่สำเร็จ: ${res.statusCode}");
    }
  }

  Future<void> useridreceiver(int userIdReceiver) async {
    if (_apiBase == null) return;
    final url = Uri.parse("$_apiBase/users/$userIdReceiver");
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final data = usersIdGetResFromJson(res.body);
      setState(() {
        getuserid = data;
      });
    } else {
      print("โหลดข้อมูล rider ไม่สำเร็จ: ${res.statusCode}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.green.shade600,
        elevation: 0,
        title: const Text(
          "รายละเอียดของสินค้า",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 🧾 Card ข้อมูล
                  Expanded(
                    child: SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 🖼️ รูปสินค้า
                            Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: _buildImage(
                                  _deliveryDetail!.pictureProduct,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // 🧾 รายละเอียด
                            const Divider(thickness: 1, color: Colors.black12),
                            const SizedBox(height: 12),

                            _buildInfoRow(
                              Icons.inventory_2_outlined,
                              "ชื่อสินค้า",
                              _deliveryDetail!.nameProduct,
                            ),
                            const SizedBox(height: 10),

                            _buildInfoRow(
                              Icons.format_list_numbered,
                              "จำนวน",
                              _deliveryDetail!.amount.toString(),
                            ),
                            const SizedBox(height: 10),

                            _buildInfoBox(
                              Icons.description_outlined,
                              "รายละเอียด",
                              _deliveryDetail!.detailProduct,
                            ),
                            const SizedBox(height: 10),

                            _buildInfoRow(
                              Icons.person_outline,
                              "ผู้รับ",
                              getuserid != null
                                  ? getuserid!.name
                                  : "กำลังโหลด...",
                            ),
                            const SizedBox(height: 10),

                            _buildInfoBox(
                              Icons.home_outlined,
                              "ที่อยู่",
                              _deliveryDetail!.addressReceiver.address,
                            ),
                            const SizedBox(height: 10),

                            _buildInfoRow(
                              Icons.location_on_outlined,
                              "พิกัด",
                              "${_deliveryDetail!.addressReceiver.lat}, ${_deliveryDetail!.addressReceiver.lng}",
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🟢 ปุ่มยืนยัน
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SenderAddress(
                              addressId:
                                  _deliveryDetail!.addressSender.addressId,
                              riderId: widget.riderId,
                              deliveryid: _deliveryDetail!.deliveryId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "ยืนยันการรับสินค้า",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🛵 Footer Rider
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          bottom: -20,
                          child: Image.asset(
                            "assets/images/img_1_cropped.png",
                            height: 110,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.green.shade600, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                  fontSize: 15,
                ),
              ),
              Text(value, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBox(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.green.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildImage(String pic) {
  if (pic.isEmpty) {
    return const Icon(Icons.image_not_supported, size: 100, color: Colors.grey);
  }

  if (pic.startsWith('data:image') || pic.length > 200) {
    try {
      final base64Str = pic.replaceAll(
        RegExp(r'^data:image/[^;]+;base64,'),
        '',
      );
      final bytes = base64Decode(base64Str);
      return Image.memory(
        bytes,
        height: 180,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.image_not_supported,
            size: 100,
            color: Colors.grey,
          );
        },
      );
    } catch (e) {
      return const Icon(Icons.broken_image, size: 100, color: Colors.redAccent);
    }
  }

  return Image.network(
    pic,
    height: 180,
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) {
      return const Icon(
        Icons.image_not_supported,
        size: 100,
        color: Colors.grey,
      );
    },
  );
}
