// lib/page/user/user_record.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/config/config.dart';
import 'package:flutter_application_1/page/user/main_user.dart';

// ✅ โมเดล history ของผู้ส่ง (ตามที่ให้มา)
import 'package:flutter_application_1/model/responses/get_sender_history.dart';

class UserRecord extends StatefulWidget {
  // เหลือเฉพาะ userIdSender ตาม requirement ใหม่
  final int userIdSender;

  const UserRecord({super.key, required this.userIdSender});

  @override
  State<UserRecord> createState() => _UserRecordState();
}

class _UserRecordState extends State<UserRecord>
    with SingleTickerProviderStateMixin {
  static const kGreen = Color(0xFF2ECC71);
  static const kCard = Color(0xFFF7FAF7);

  String? _apiBase;
  bool _loading = true;
  String? _error;

  GetSenderHistory? _data; // ✅ ใช้โมเดลใหม่

  @override
  void initState() {
    super.initState();
    _initAndFetch();
  }

  Future<void> _initAndFetch() async {
    try {
      final cfg = await Configuration.getConfig();
      _apiBase = (cfg['apiEndpoint'] as String?)?.trim();
      await _fetchSenderHistory();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'โหลดการตั้งค่าไม่สำเร็จ: $e';
      });
    }
  }

  Future<void> _fetchSenderHistory() async {
    if (_apiBase == null) {
      setState(() {
        _loading = false;
        _error = 'ไม่พบ apiEndpoint';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final url = Uri.parse('$_apiBase/sender/history/${widget.userIdSender}');
      final res = await http.get(url);

      if (!mounted) return;

      if (res.statusCode == 200) {
        final parsed = getSenderHistoryFromJson(res.body);
        setState(() {
          _data = parsed;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'โหลดไม่สำเร็จ: HTTP ${res.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'เกิดข้อผิดพลาด: $e';
      });
    }
  }

  // --- helpers (UI เท่านั้น) -------------------------------------------------
  ImageProvider _imgFrom(
    String? src, {
    String placeholder = 'assets/images/no_image.png',
  }) {
    if (src == null || src.isEmpty) return AssetImage(placeholder);
    try {
      if (src.startsWith('http')) return NetworkImage(src);
      final cleaned = src
          .replaceAll(RegExp(r'^data:image/[^;]+;base64,'), '')
          .trim();
      final bytes = base64Decode(cleaned);
      return MemoryImage(bytes);
    } catch (_) {
      return AssetImage(placeholder);
    }
  }

  Widget _chipStatus(String status) {
    Color c;
    switch (status.toLowerCase()) {
      case 'waiting':
        c = Colors.orange;
        break;
      case 'delivering':
        c = Colors.blue;
        break;
      case 'finish':
        c = Colors.green;
        break;
      default:
        c = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(.12),
        border: Border.all(color: c.withOpacity(.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_shipping, size: 14, color: c),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(color: c, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _imageCell(ImageProvider img, String caption) {
    final isNoImg = img is AssetImage && img.assetName.contains('no_image');
    return Column(
      children: [
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE9ECE8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image(image: img, fit: BoxFit.cover),
                if (isNoImg)
                  const Center(
                    child: Text(
                      'ยังไม่มีรูป',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          caption,
          style: const TextStyle(fontSize: 12.5, color: Colors.black87),
        ),
      ],
    );
  }

  // --- UI --------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            color: kGreen,
            padding: const EdgeInsets.only(top: 45, bottom: 12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Text(
                  'ZapGo',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Positioned(
                  left: 0,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MainUser(userid: widget.userIdSender),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Title row
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            alignment: Alignment.centerLeft,
            child: const Text(
              'ประวัติการส่งของ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),

          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _fetchSenderHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Icon(Icons.error_outline, color: Colors.red.shade400, size: 42),
            const SizedBox(height: 8),
            Center(child: Text(_error!, textAlign: TextAlign.center)),
          ],
        ),
      );
    }
    if (_data == null || _data!.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchSenderHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text(
                'ยังไม่มีประวัติการส่งของ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    // ✅ แสดง list card จาก GetSenderHistory.items
    return RefreshIndicator(
      onRefresh: _fetchSenderHistory,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        itemCount: _data!.items.length,
        itemBuilder: (context, index) {
          final it = _data!.items[index];

          // รูปจาก assignment (รูปตอนรับ/ส่ง)
          final pic2 = _imgFrom(it.pictureStatus2);
          final pic3 = _imgFrom(it.pictureStatus3);

          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 300 + index * 70),
            curve: Curves.easeOutCubic,
            builder: (context, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, 10 * (1 - v)),
                child: child,
              ),
            ),
            child: Card(
              color: kCard,
              elevation: 6,
              shadowColor: kGreen.withOpacity(.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.only(bottom: 14),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // หัวการ์ด: สถานะ + จำนวน + ชิป
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar เล็ก ๆ (ไอคอนคนแทนรูปสินค้า)
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.06),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'สรุปงานส่ง',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Text(
                                    'สถานะ: ',
                                    style: TextStyle(color: Colors.black87),
                                  ),
                                  _chipStatus(it.status),
                                ],
                              ),
                              Text(
                                'จำนวน: ${it.amount}',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    Divider(color: Colors.black.withOpacity(.08), height: 22),

                    // หัวข้อรายละเอียดผู้จัดส่ง
                    Row(
                      children: const [
                        Text(
                          'รายละเอียดผู้จัดส่ง',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.check_circle, size: 18, color: Colors.green),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // รูป 2 ช่อง: ตอนรับ / ตอนส่งเสร็จสิ้น
                    Row(
                      children: [
                        Expanded(child: _imageCell(pic2, 'รูปตอนรับของ')),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _imageCell(pic3, 'รูปตอนส่งของเสร็จสิ้น'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    // แถบข้อมูลย่อย (IDs)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _miniChip('delivery_id: ${it.deliveryId}'),
                        _miniChip('rider_id: ${it.riderId}'),
                        _miniChip('assi_id: ${it.assiId}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _miniChip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE9ECE8)),
      borderRadius: BorderRadius.circular(10),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Text(text, style: const TextStyle(fontSize: 12.5)),
  );
}
