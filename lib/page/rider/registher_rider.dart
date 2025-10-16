import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:flutter_application_1/config/config.dart';
import 'package:flutter_application_1/model/requsts/register_rider_post_req.dart';
import 'package:flutter_application_1/page/login.dart';

class RegistherRider extends StatefulWidget {
  const RegistherRider({super.key});

  @override
  State<RegistherRider> createState() => _RegistherRiderState();
}

class _RegistherRiderState extends State<RegistherRider> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();

  String? _selectedVehicle;
  String? _apiBase;
  bool _loading = false;

  File? _profileImage;
  File? _vehicleImage;
  String? _profileBase64;
  String? _vehicleBase64;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    Configuration.getConfig()
        .then((cfg) {
          setState(() => _apiBase = (cfg['apiEndpoint'] as String?)?.trim());
        })
        .catchError((e) {
          _showErrorDialog("ข้อผิดพลาด", "อ่าน config ไม่ได้: $e");
        });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isProfile) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.photo_camera, color: Colors.green),
                title: const Text("ถ่ายรูปด้วยกล้อง"),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  var status = await Permission.camera.request();
                  if (!status.isGranted) {
                    _showErrorDialog(
                      "การเข้าถึงถูกปฏิเสธ",
                      "ไม่ได้อนุญาตให้ใช้กล้อง",
                    );
                    return;
                  }

                  final picked = await _picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 50,
                    maxWidth: 800,
                  );

                  if (picked != null) {
                    final bytes = await picked.readAsBytes();
                    setState(() {
                      if (isProfile) {
                        _profileImage = File(picked.path);
                        _profileBase64 = base64Encode(bytes);
                      } else {
                        _vehicleImage = File(picked.path);
                        _vehicleBase64 = base64Encode(bytes);
                      }
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text("เลือกจากแกลเลอรี"),
                onTap: () async {
                  Navigator.of(ctx).pop();

                  final picked = await _picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 50,
                    maxWidth: 800,
                  );

                  if (picked != null) {
                    final bytes = await picked.readAsBytes();
                    setState(() {
                      if (isProfile) {
                        _profileImage = File(picked.path);
                        _profileBase64 = base64Encode(bytes);
                      } else {
                        _vehicleImage = File(picked.path);
                        _vehicleBase64 = base64Encode(bytes);
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _registerRider() async {
    if (_apiBase == null || _apiBase!.isEmpty) {
      _showErrorDialog("ขออภัย", "ยังไม่ได้ตั้งค่า API Endpoint");
      return;
    }

    if (_nameCtrl.text.isEmpty ||
        _phoneCtrl.text.isEmpty ||
        _passCtrl.text.isEmpty ||
        _plateCtrl.text.isEmpty ||
        _selectedVehicle == null) {
      _showErrorDialog("ขออภัย", "กรุณากรอกข้อมูลให้ครบถ้วน");
      return;
    }

    setState(() => _loading = true);

    try {
      final req = RegisterRiderPostReq(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        password: _passCtrl.text,
        plateNumber: _plateCtrl.text.trim(),
        carType: _selectedVehicle!,
        imageCar: _vehicleBase64 ?? "default_car.png",
        picture: _profileBase64 ?? "default.png",
      );

      final res = await http.post(
        Uri.parse('$_apiBase/register/rider'),
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: registerRiderPostReqToJson(req),
      );

      log("REGISTER RIDER status=${res.statusCode}");
      log("REGISTER RIDER body=${res.body}");

      if (res.statusCode == 201 || res.statusCode == 200) {
        if (!mounted) return;
        _showSuccessPopup();
      } else {
        if (!mounted) return;
        _showErrorDialog(
          "ผิดพลาด",
          "สมัครไรเดอร์ไม่สำเร็จ (${res.statusCode})",
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog("ข้อผิดพลาด", e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccessPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF2ecc71),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Image.asset("assets/images/img_2_cropped.png", width: 120),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "ลงทะเบียนสำเร็จ ✅",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: "Sarabun",
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "ตกลง",
                style: TextStyle(color: Colors.white, fontFamily: "Sarabun"),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: const TextStyle(fontFamily: "Sarabun")),
        content: Text(message, style: const TextStyle(fontFamily: "Sarabun")),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("ตกลง", style: TextStyle(fontFamily: "Sarabun")),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // 🟢 Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              color: Colors.green.shade600,
              child: const Center(
                child: Text(
                  "สมัครไรเดอร์",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: "Sarabun",
                  ),
                ),
              ),
            ),

            // 📋 Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _circleOption(
                          _profileImage,
                          "เพิ่มรูปโปรไฟล์",
                          true,
                          "assets/images/profile_rider.png",
                        ),
                        _circleOption(
                          _vehicleImage,
                          "เพิ่มยานพาหนะ",
                          false,
                          "assets/images/img_3.png",
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildTextField("ชื่อ-นามสกุล", _nameCtrl),
                    const SizedBox(height: 12),
                    _buildTextField(
                      "เบอร์โทร",
                      _phoneCtrl,
                      keyboard: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField("รหัสผ่าน", _passCtrl, obscure: true),
                    const SizedBox(height: 12),
                    _buildTextField("ทะเบียนรถ", _plateCtrl),
                    const SizedBox(height: 12),

                    // 🚘 Dropdown vehicle
                    DropdownButtonFormField<String>(
                      value: _selectedVehicle,
                      items: const [
                        DropdownMenuItem(
                          value: "มอไซค์",
                          child: Text("มอไซค์"),
                        ),
                        DropdownMenuItem(
                          value: "รถยนต์",
                          child: Text("รถยนต์"),
                        ),
                        DropdownMenuItem(value: "กระบะ", child: Text("กระบะ")),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedVehicle = value),
                      decoration: InputDecoration(
                        labelText: "ประเภทยานพาหนะ",
                        labelStyle: const TextStyle(fontFamily: "Sarabun"),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ✅ ปุ่มสมัคร
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _registerRider,
                        icon: const Icon(
                          Icons.delivery_dining,
                          color: Colors.white,
                        ),
                        label: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "สมัครไรเดอร์",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontFamily: "Sarabun",
                                ),
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                      child: const Text(
                        "กลับไปหน้าเข้าสู่ระบบ",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue,
                          fontFamily: "Sarabun",
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleOption(
    File? imageFile,
    String label,
    bool isProfile,
    String placeholder,
  ) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _pickImage(isProfile),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: imageFile != null
                    ? FileImage(imageFile)
                    : AssetImage(placeholder),
              ),
              const CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white,
                child: Icon(Icons.add_circle, color: Colors.green, size: 30),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontFamily: "Sarabun"),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String hint,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      style: const TextStyle(fontFamily: "Sarabun"),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(fontFamily: "Sarabun"),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
