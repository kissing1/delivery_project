import 'dart:developer';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/config/config.dart';
import 'package:flutter_application_1/model/requsts/register_user_post_req.dart';
import 'package:flutter_application_1/page/login.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  String? _apiBase;
  bool _loading = false;

  File? _profileImage;
  String? _profileBase64;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    Configuration.getConfig()
        .then((cfg) {
          setState(() => _apiBase = (cfg['apiEndpoint'] as String?)?.trim());
        })
        .catchError((e) {
          _showDialog("ข้อผิดพลาด", "อ่าน config ไม่ได้: $e");
        });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera, color: Colors.green),
                title: const Text("ถ่ายรูปด้วยกล้อง"),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final picked = await _picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 50,
                    maxWidth: 800,
                  );
                  if (picked != null) {
                    final bytes = await picked.readAsBytes();
                    setState(() {
                      _profileImage = File(picked.path);
                      _profileBase64 = base64Encode(bytes);
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
                      _profileImage = File(picked.path);
                      _profileBase64 = base64Encode(bytes);
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _register() async {
    if (_apiBase == null || _apiBase!.isEmpty) {
      _showDialog("ขออภัย", "ยังไม่ได้ตั้งค่า API Endpoint");
      return;
    }

    if (_nameCtrl.text.isEmpty ||
        _phoneCtrl.text.isEmpty ||
        _passCtrl.text.isEmpty) {
      _showDialog("ขออภัย", "กรุณากรอกข้อมูลให้ครบถ้วน");
      return;
    }

    setState(() => _loading = true);

    try {
      final req = RegisterUserPostReq(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        password: _passCtrl.text,
        picture: _profileBase64 ?? "default.png",
      );

      final res = await http.post(
        Uri.parse('$_apiBase/register/user'),
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: registerUserPostReqToJson(req),
      );

      log('REGISTER status=${res.statusCode}');
      log('REGISTER body=${res.body}');

      if (res.statusCode == 201 || res.statusCode == 200) {
        if (!mounted) return;
        _showDialog("สำเร็จ", "ลงทะเบียนเสร็จสิ้น", goLogin: true);
      } else {
        if (!mounted) return;
        _showDialog("ผิดพลาด", "สมัครสมาชิกไม่สำเร็จ (${res.statusCode})");
      }
    } catch (e) {
      if (!mounted) return;
      _showDialog("ข้อผิดพลาด", e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showDialog(String title, String message, {bool goLogin = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Center(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (goLogin) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (route) => false,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "ตกลง",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // 🟩 Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: const Text(
                "สมัครผู้ใช้",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(24),
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 🧍 รูปโปรไฟล์
                      _circleOption(
                        _profileImage,
                        "เพิ่มรูปโปรไฟล์",
                        "assets/images/Img.png",
                      ),
                      const SizedBox(height: 24),

                      // 📝 ฟอร์ม
                      _buildTextField(
                        "ชื่อ-นามสกุล",
                        _nameCtrl,
                        icon: Icons.person,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        "เบอร์โทร",
                        _phoneCtrl,
                        keyboard: TextInputType.phone,
                        icon: Icons.phone,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        "รหัสผ่าน",
                        _passCtrl,
                        obscure: true,
                        icon: Icons.lock,
                      ),
                      const SizedBox(height: 24),

                      // 🟢 ปุ่มสมัคร
                      ElevatedButton.icon(
                        onPressed: _loading ? null : _register,
                        icon: const Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                        ),
                        label: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                "สมัครสมาชิก",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 32,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                          );
                        },
                        child: const Text(
                          "กลับไปหน้าเข้าสู่ระบบ",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
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

  Widget _circleOption(File? imageFile, String label, String placeholder) {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: imageFile != null
                    ? FileImage(imageFile)
                    : AssetImage(placeholder) as ImageProvider,
              ),
              const CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white,
                child: Icon(Icons.add_circle, color: Colors.green, size: 30),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 15)),
      ],
    );
  }

  Widget _buildTextField(
    String hint,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    IconData? icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: icon != null
            ? Icon(icon, color: Colors.green.shade600)
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.green.shade600, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
