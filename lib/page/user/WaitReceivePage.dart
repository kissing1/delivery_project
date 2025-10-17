import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/config/config.dart';

import 'package:flutter_application_1/model/responses/receiver_by_get_res.dart';
import 'package:http/http.dart' as http;

class WaitReceivePage extends StatefulWidget {
  final int userId;
  const WaitReceivePage({super.key, required this.userId});

  @override
  State<WaitReceivePage> createState() => _WaitReceivePageState();
}

class _WaitReceivePageState extends State<WaitReceivePage> {
  bool _loading = true;
  String? _apiBase;
  List<Item> _items = [];
  Map<int, String> _senderNames = {}; // 🧑 เก็บชื่อผู้ส่ง

  @override
  void initState() {
    super.initState();
    _fetchDeliveries();
  }

  Future<void> _fetchDeliveries() async {
    final cfg = await Configuration.getConfig();
    _apiBase = (cfg['apiEndpoint'] as String?)?.trim();
    if (_apiBase == null) return;

    setState(() => _loading = true);

    final res = await http.get(
      Uri.parse("$_apiBase/deliveries/by-receiver/${widget.userId}"),
    );

    if (res.statusCode == 200) {
      final data = byReceiverGetResFromJson(res.body);
      final acceptItems = data.items
          .where((item) => item.status == 'accept')
          .toList();

      setState(() {
        _items = acceptItems;
      });

      // 🧑 ดึงชื่อผู้ส่งเพิ่ม
      for (var item in acceptItems) {
        await _fetchSenderName(item.userIdSender);
      }
    } else {
      debugPrint("❌ Error ${res.statusCode}: ${res.body}");
    }

    setState(() => _loading = false);
  }

  Future<void> _fetchSenderName(int senderId) async {
    if (_senderNames.containsKey(senderId)) return; // ✅ ป้องกันดึงซ้ำ
    final res = await http.get(Uri.parse("$_apiBase/users/$senderId"));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final name = data["name"] ?? "ไม่ระบุชื่อ";
      setState(() => _senderNames[senderId] = name);
    } else {
      setState(() => _senderNames[senderId] = "ไม่พบชื่อ");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("รอรับของ"),
        backgroundColor: const Color(0xFF2ECC71),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDeliveries,
        child: _items.isEmpty
            ? const Center(
                child: Text(
                  "ยังไม่มีรายการรอรับของ",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];

                  // 📸 decode รูปภาพ
                  final imgBytes = base64Decode(
                    item.pictureProduct.replaceAll(
                      RegExp(r'^data:image/[^;]+;base64,'),
                      '',
                    ),
                  );

                  final senderName =
                      _senderNames[item.userIdSender] ?? "กำลังโหลด...";

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          imgBytes,
                          width: 50,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(item.nameProduct),
                      subtitle: Text(
                        "ผู้ส่ง: $senderName\nสถานะ: ${item.status}",
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showDetailDialog(item, senderName),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _showDetailDialog(Item item, String senderName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(item.nameProduct),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("จำนวน: ${item.amount}"),
            Text("รายละเอียด: ${item.detailProduct}"),
            Text("สถานะ: ${item.status}"),
            Text("ผู้ส่ง: $senderName"),
            Text("เบอร์โทรผู้รับ: ${item.phoneReceiver}"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ปิด"),
          ),
        ],
      ),
    );
  }
}
