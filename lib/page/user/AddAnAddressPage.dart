import 'package:flutter/material.dart';
import 'package:flutter_application_1/config/config.dart';
import 'package:flutter_application_1/model/requsts/add_address_post_req.dart';
import 'package:flutter_application_1/page/user/MapPage.dart';
import 'package:http/http.dart' as http;

class AddAnAddressPage extends StatefulWidget {
  final int userId;
  const AddAnAddressPage({super.key, required this.userId});

  @override
  State<AddAnAddressPage> createState() => _AddAnAddressPageState();
}

class _AddAnAddressPageState extends State<AddAnAddressPage> {
  final _addressCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();

  String? _apiBase;

  @override
  void initState() {
    super.initState();
    Configuration.getConfig().then((cfg) {
      setState(() => _apiBase = (cfg['apiEndpoint'] as String?)?.trim());
    });
  }

  Future<void> _submitAddress() async {
    if (_apiBase == null) return;

    final body = AddAddressPostReq(
      userId: widget.userId,
      address: _addressCtrl.text.trim(),
      lat: double.tryParse(_latCtrl.text.trim()) ?? 0.0,
      lng: double.tryParse(_lngCtrl.text.trim()) ?? 0.0,
    );

    final res = await http.post(
      Uri.parse("$_apiBase/users/addresses"),
      headers: {"Content-Type": "application/json; charset=utf-8"},
      body: addAddressPostReqToJson(body),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      Navigator.pop(context, true); // ✅ กลับไปหน้าสมุดที่อยู่ พร้อม refresh
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("บันทึกไม่สำเร็จ: ${res.body}")));
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MapPage()),
    );

    if (result != null && result is Map<String, double>) {
      setState(() {
        _latCtrl.text = result["lat"].toString();
        _lngCtrl.text = result["lng"].toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.green,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: const Center(
              child: Text(
                "ZapGo",
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("ที่อยู่"),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _addressCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "กรอกที่อยู่ของคุณ",
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ✅ เลือกพิกัด
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _pickLocation,
                        child: Image.asset(
                          "assets/images/img_5.png",
                          width: 60,
                          height: 60,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // ช่องละติจูด
                      Expanded(
                        child: TextField(
                          controller: _latCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "ละติจูด",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // ช่องลองจิจูด
                      Expanded(
                        child: TextField(
                          controller: _lngCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "ลองจิจูด",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 14,
                        ),
                      ),
                      onPressed: _submitAddress,
                      child: const Text(
                        "ยืนยัน",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
