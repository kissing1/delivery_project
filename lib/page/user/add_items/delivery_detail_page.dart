import 'dart:convert';
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
    required deliveryId,
  });

  @override
  State<DeliveryDetailPage> createState() => _DeliveryDetailPageState();
}

class _DeliveryDetailPageState extends State<DeliveryDetailPage> {
  String? _apiBase;
  String receiverName = "-";
  String receiverAddress = "-";
  String coordinate = "-";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfigAndFetchData();
  }

  // ✅ โหลดค่า config และ fetch ข้อมูลผู้รับ
  Future<void> _loadConfigAndFetchData() async {
    try {
      final cfg = await Configuration.getConfig();
      _apiBase = (cfg['apiEndpoint'] as String?)?.trim();

      // ✅ ตรวจว่ามีค่าและไม่ว่าง
      if ((_apiBase ?? '').isNotEmpty) {
        await _fetchReceiverDetails();
      }
    } catch (e) {
      debugPrint("⚠️ โหลด config หรือข้อมูลไม่ได้: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ✅ ดึงข้อมูลผู้รับและที่อยู่จาก API
  Future<void> _fetchReceiverDetails() async {
    final userId = widget.deliveryData["user_id_receiver"];
    final addressId = widget.deliveryData["address_id_receiver"];

    try {
      // 🔹 ดึงชื่อผู้รับ
      final resUser = await http.get(Uri.parse("$_apiBase/users/$userId"));
      if (resUser.statusCode == 200) {
        final userData = usersIdGetResFromJson(resUser.body);
        receiverName = userData.name.isNotEmpty ? userData.name : "-";
      }

      // 🔹 ดึงที่อยู่ผู้รับ
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
    final imageBase64 = widget.deliveryData['picture_product'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF32BD6C),
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
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.black12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (imageBase64 != null)
                            Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  const Base64Decoder().convert(imageBase64),
                                  height: 180,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          _buildRow(
                            "ชื่อสินค้า:",
                            widget.deliveryData['name_product'],
                          ),
                          _buildRow(
                            "รายละเอียด:",
                            widget.deliveryData['detail_product'],
                          ),
                          const Divider(height: 20),
                          _buildRow("ผู้รับ:", receiverName),
                          _buildRow("ที่อยู่:", receiverAddress),
                          _buildRow("พิกัด:", coordinate),
                          const Divider(height: 20),
                          _buildRow("จำนวน:", widget.deliveryData['amount']),
                          _buildRow("สถานะ:", widget.deliveryData['status']),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),

          // ✅ Footer (ถนน + รถ)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Image.asset(
                  "assets/images/img_8_cropped.png",
                  fit: BoxFit.cover,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Image.asset(
                    "assets/images/delivery_scooter.png",
                    width: 150,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ แถวข้อความสวย ๆ
  Widget _buildRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label ",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: "Roboto",
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? '-',
              style: const TextStyle(fontFamily: "Roboto"),
            ),
          ),
        ],
      ),
    );
  }
}
