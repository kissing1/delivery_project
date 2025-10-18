import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart'; // ใช้ตอน share รูป
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class QRInstallPage extends StatefulWidget {
  final String apkUrl; // ใส่ลิงก์ APK หรือ Play Store ก็ได้
  const QRInstallPage({super.key, required this.apkUrl});

  @override
  State<QRInstallPage> createState() => _QRInstallPageState();
}

class _QRInstallPageState extends State<QRInstallPage> {
  static const kGreen = Color(0xFF2ECC71);
  final _qrKey = GlobalKey();

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.apkUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('คัดลอกลิงก์แล้ว ✅')));
  }

  Future<void> _shareLink() async {
    await Share.share(widget.apkUrl, subject: 'ZapGo APK');
  }

  /// แปลง QR เป็นภาพแล้วแชร์ (สร้างไฟล์ชั่วคราว)
  Future<void> _shareQRImage() async {
    try {
      // เรนเดอร์ภาพจาก RepaintBoundary
      final boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/zapgo_qr.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'สแกนเพื่อติดตั้ง ZapGo');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('แชร์รูปไม่สำเร็จ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kGreen,
        title: const Text(
          'ติดตั้ง ZapGo',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        children: [
          // การ์ด QR
          Card(
            color: const Color(0xFFF7FAF7),
            elevation: 6,
            shadowColor: kGreen.withOpacity(.25),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Column(
                children: [
                  // โลโก้ + ชื่อ
                  Column(
                    children: [
                      Container(
                        width: 74,
                        height: 74,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Image.asset(
                            'assets/images/img_1_cropped.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'ZapGo',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: kGreen,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'สแกนเพื่อติดตั้ง / เปิดลิงก์ดาวน์โหลด',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // QR
                  RepaintBoundary(
                    key: _qrKey,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: widget.apkUrl,
                        version: QrVersions.auto,
                        size: 240,
                        gapless: true,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                        embeddedImage: const AssetImage(
                          'assets/images/img_1_cropped.png',
                        ),
                        embeddedImageStyle: const QrEmbeddedImageStyle(
                          size: Size(48, 48),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ลิงก์ (ตัดยาว)
                  SelectableText(
                    widget.apkUrl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // ปุ่มแอ็กชัน
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _copyLink,
                  icon: const Icon(Icons.copy, color: Colors.white),
                  label: const Text(
                    'คัดลอกลิงก์',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _shareLink,
                  icon: const Icon(Icons.ios_share, color: Colors.white),
                  label: const Text(
                    'แชร์ลิงก์',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: kGreen.withOpacity(.75)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _shareQRImage,
            icon: const Icon(Icons.qr_code_2),
            label: const Text('แชร์รูป QR'),
          ),
        ],
      ),
    );
  }
}
