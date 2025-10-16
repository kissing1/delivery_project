import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/page/gps_get.dart';
import 'package:flutter_application_1/page/rider/main_rider.dart';
import 'package:flutter_application_1/page/rider/registher_rider.dart';
import 'package:flutter_application_1/page/user/register_user.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/model/requsts/login_request.dart';
import 'package:flutter_application_1/model/responses/login_response.dart';
import 'package:flutter_application_1/model/user_item.dart';
import 'package:flutter_application_1/config/config.dart';
import 'package:flutter_application_1/page/user/main_user.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  String? _apiBase;
  bool _loading = false;

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
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_apiBase == null || _apiBase!.isEmpty) {
      _showErrorDialog("ขออภัย", "ยังไม่ได้ตั้งค่า API Endpoint");
      return;
    }

    setState(() => _loading = true);

    try {
      final req = LoginRequest(
        phone: _phoneCtrl.text.trim(),
        password: _passCtrl.text,
      );

      final res = await http.post(
        Uri.parse('$_apiBase/login'),
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: loginRequestToJson(req),
      );

      log('LOGIN status=${res.statusCode}');
      log('LOGIN body=${res.body}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['id'] != null && data['name'] != null) {
          final login = LoginResponse.fromJson(data);

          final userItem = UserItem(
            id: login.id,
            name: login.name,
            phone: login.phone,
            role: login.roleInt,
          );

          if (!mounted) return;

          if (userItem.role == 1) {
            int user_id = int.tryParse(userItem.id) ?? -1;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => MainRider(riderid: user_id)),
              (route) => false,
            );
          } else {
            int user_id = int.tryParse(userItem.id) ?? -1;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => MainUser(userid: user_id)),
              (route) => false,
            );
          }
        } else {
          if (!mounted) return;
          _showErrorDialog("ขออภัย", "ข้อมูลผู้ใช้ไม่ถูกต้อง");
        }
      } else if (res.statusCode == 401) {
        if (!mounted) return;
        _showErrorDialog("ขออภัย", "เบอร์โทรหรือรหัสผ่านไม่ถูกต้อง");
      } else {
        if (!mounted) return;
        _showErrorDialog(
          "เข้าสู่ระบบล้มเหลว",
          "เกิดข้อผิดพลาดจากเซิร์ฟเวอร์ (${res.statusCode})",
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog("ข้อผิดพลาด", e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
                child: Column(
                  children: [
                    Image.asset("assets/images/img_3.png", width: 100),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
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
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    "ตกลง",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              children: [
                // 🟢 Header
                Container(
                  width: double.infinity,
                  color: Colors.green.shade600,
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      const Text(
                        "ZapGo",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 250,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              top: -20,
                              left: -30,
                              child: Image.asset(
                                "assets/images/img_2.png",
                                width: 90,
                              ),
                            ),
                            Positioned(
                              top: 10,
                              right: -50,
                              child: Image.asset(
                                "assets/images/img_2.png",
                                width: 80,
                              ),
                            ),
                            Container(
                              width: 200,
                              height: 200,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Image.asset(
                              "assets/images/img_1.png",
                              width: 230,
                              height: 230,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Delivery Express Presentation",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),

                // 📋 Login Box
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 30,
                  ),
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: "เบอร์โทร",
                            prefixIcon: Icon(
                              Icons.phone,
                              color: Colors.green.shade600,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passCtrl,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: "รหัสผ่าน",
                            prefixIcon: Icon(
                              Icons.lock,
                              color: Colors.green.shade600,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _loading ? null : _submit,
                          icon: const Icon(Icons.login, color: Colors.white),
                          label: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "เข้าสู่ระบบ",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterPage(),
                                  ),
                                );
                              },
                              child: const Text(
                                "สมัครผู้ใช้",
                                style: TextStyle(
                                  fontSize: 14,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const RegistherRider(),
                                  ),
                                );
                              },
                              child: const Text(
                                "สมัครไรเดอร์",
                                style: TextStyle(
                                  fontSize: 14,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const RiderLocationRealtime(),
                                  ),
                                );
                              },
                              child: const Text(
                                "GPS",
                                style: TextStyle(
                                  fontSize: 14,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
