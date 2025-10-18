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

  // ===== THEME (Delivery Premium) =====
  static const _kBg = Color(0xFFF6FAF8);
  static const _kGreen = Color(0xFF32BD6C);
  static const _kGreenDark = Color(0xFF249B58);
  static const _kPink = Color(0xFFFF5C8A);
  static const _kInk = Color(0xFF101214);

  @override
  void initState() {
    super.initState();
    Configuration.getConfig().then((cfg) {
      if (!mounted) return;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text("บันทึกไม่สำเร็จ: ${res.body}"),
        ),
      );
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

  // ===== UI helpers (เฉพาะหน้าตา) =====
  InputDecoration _dec({
    required String label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    // ignore: unused_element_parameter
    int? maxLines,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black12.withOpacity(.15)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black12.withOpacity(.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kGreen, width: 1.6),
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
        letterSpacing: .2,
      ),
    ),
  );

  Widget _pillChip(IconData icon, String text, {Color color = _kGreen}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, _kGreenDark, .25)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 6),
            color: color.withOpacity(.28),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: .3,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      // ===== Header กราเดียนต์เดลิเวอรี่ =====
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
                "เพิ่มที่อยู่ใหม่",
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
                  letterSpacing: .3,
                ),
              ),
            ],
          ),
        ),
      ),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
          children: [
            // แถวข้อมูลบนสุด
            Row(
              children: [
                _pillChip(
                  Icons.person_pin_circle_rounded,
                  "User: ${widget.userId}",
                ),
                const SizedBox(width: 8),
                _pillChip(Icons.location_on_rounded, "Address", color: _kPink),
              ],
            ),
            const SizedBox(height: 14),

            // ===== Card แบบพรีเมียม =====
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12.withOpacity(.06)),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 18,
                    spreadRadius: 1,
                    offset: const Offset(0, 10),
                    color: Colors.black.withOpacity(.08),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle("รายละเอียดที่อยู่"),
                    TextField(
                      controller: _addressCtrl,
                      maxLines: 4,
                      decoration: _dec(
                        label: "ที่อยู่ของคุณ",
                        hint:
                            "บ้านเลขที่ / อาคาร / ถนน / ตำบล / อำเภอ / จังหวัด / รหัสไปรษณีย์",
                        prefixIcon: const Icon(Icons.home_work_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _sectionTitle("พิกัด (ละติจูด/ลองจิจูด)"),

                    // แถวเลือกพิกัด
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ปุ่มเลือกจากแผนที่
                        InkWell(
                          onTap: _pickLocation,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_kGreen, _kGreenDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 12,
                                  offset: const Offset(0, 8),
                                  color: _kGreenDark.withOpacity(.25),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.map_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Lat
                        Expanded(
                          child: TextField(
                            controller: _latCtrl,
                            keyboardType: TextInputType.number,
                            decoration: _dec(
                              label: "ละติจูด",
                              prefixIcon: const Icon(Icons.my_location_rounded),
                              suffixIcon: _latCtrl.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'ล้าง',
                                      icon: const Icon(Icons.clear_rounded),
                                      onPressed: () =>
                                          setState(() => _latCtrl.clear()),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Lng
                        Expanded(
                          child: TextField(
                            controller: _lngCtrl,
                            keyboardType: TextInputType.number,
                            decoration: _dec(
                              label: "ลองจิจูด",
                              prefixIcon: const Icon(Icons.explore_rounded),
                              suffixIcon: _lngCtrl.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'ล้าง',
                                      icon: const Icon(Icons.clear_rounded),
                                      onPressed: () =>
                                          setState(() => _lngCtrl.clear()),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),

            // ปุ่มยืนยันแบบพรีเมียม (Gradient + เงา)
            GestureDetector(
              onTap: _submitAddress,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 18,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kPink, _kGreen],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                      color: _kGreenDark.withOpacity(.25),
                    ),
                  ],
                ),
                child: const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.save_rounded, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        "ยืนยัน",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
