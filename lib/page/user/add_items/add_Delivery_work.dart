import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/config/config.dart';
import 'package:flutter_application_1/model/requsts/address_list_post_req.dart';
import 'package:flutter_application_1/model/requsts/searchphone_post_req.dart';
import 'package:flutter_application_1/model/responses/address_list_post_res.dart';
import 'package:flutter_application_1/model/responses/DElivery_sender_post_res.dart'
    as sender;
import 'package:flutter_application_1/model/responses/searchphone_get_res.dart';
import 'package:flutter_application_1/page/user/main_user.dart';
import 'package:flutter_application_1/providers/delivery_provider.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class AddDeliveryWork extends StatefulWidget {
  final int userIdSender;
  const AddDeliveryWork({super.key, required this.userIdSender});

  @override
  State<AddDeliveryWork> createState() => _AddDeliveryWorkState();
}

class _AddDeliveryWorkState extends State<AddDeliveryWork> {
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _detailCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  String? _apiBase;
  bool _isSearching = false;
  bool _notFound = false;

  int? _userIdReceiver;
  int? _addressIdReceiver;
  int? _addressIdSender;
  int? _selectedSenderIndex;

  String? _receiverName; // ✅ เพิ่มไว้เก็บชื่อผู้รับ
  AddressListPostRes? _receiverAddressResult;
  AddressListPostRes? _senderAddressResult;

  File? _imageFile;
  String? _imageBase64;

  bool _showSelectSenderAddress = false;
  bool _showCreateProduct = false;

  @override
  void initState() {
    super.initState();
    Configuration.getConfig().then((cfg) {
      setState(() => _apiBase = (cfg['apiEndpoint'] as String?)?.trim());
    });
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _detailCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  // ✅ ค้นหาผู้รับ
  Future<void> _searchReceiver() async {
    if (_apiBase == null) return;
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;

    setState(() {
      _isSearching = true;
      _notFound = false;
    });

    try {
      final req = SearchphonePostReq(phone: phone);
      final res = await http.post(
        Uri.parse('$_apiBase/users/by-phone'),
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: searchphonePostReqToJson(req),
      );

      if (res.statusCode == 200) {
        final user = searchphoneGetResFromJson(res.body);
        _userIdReceiver = user.userId;
        _receiverName = user.name; // ✅ เก็บชื่อผู้รับไว้เลย

        // ดึงที่อยู่ของผู้รับ
        final reqList = AddressListPostReq(userId: user.userId, limit: 10);
        final resList = await http.post(
          Uri.parse('$_apiBase/users/addresses/list'),
          headers: const {'Content-Type': 'application/json; charset=utf-8'},
          body: addressListPostReqToJson(reqList),
        );

        if (resList.statusCode == 200) {
          setState(() {
            _receiverAddressResult = addressListPostResFromJson(resList.body);
          });
        } else {
          setState(() => _notFound = true);
        }
      } else {
        setState(() => _notFound = true);
      }
    } catch (e) {
      debugPrint("❌ Error: $e");
      setState(() => _notFound = true);
    } finally {
      setState(() => _isSearching = false);
    }
  }

  // ✅ ดึงที่อยู่ของผู้ส่ง
  Future<void> _fetchSenderAddresses() async {
    if (_apiBase == null) return;
    try {
      final reqList = AddressListPostReq(
        userId: widget.userIdSender,
        limit: 10,
      );
      final res = await http.post(
        Uri.parse('$_apiBase/users/addresses/list'),
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: addressListPostReqToJson(reqList),
      );

      if (res.statusCode == 200) {
        setState(() {
          _senderAddressResult = addressListPostResFromJson(res.body);
          _showSelectSenderAddress = true;
        });
      }
    } catch (e) {
      debugPrint("⚠️ Error fetching sender addresses: $e");
    }
  }

  // ✅ เลือกรูปภาพสินค้า
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
                    imageQuality: 80,
                    maxWidth: 800,
                  );
                  if (picked != null) {
                    final file = File(picked.path);
                    final bytes = await file.readAsBytes();

                    final decoded = img.decodeImage(bytes);
                    if (decoded != null) {
                      final resized = img.copyResize(decoded, width: 800);
                      final compressed = img.encodeJpg(resized, quality: 60);
                      setState(() {
                        _imageFile = file;
                        _imageBase64 = base64Encode(compressed);
                      });
                    }
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
                    imageQuality: 80,
                    maxWidth: 800,
                  );
                  if (picked != null) {
                    final file = File(picked.path);
                    final bytes = await file.readAsBytes();

                    final decoded = img.decodeImage(bytes);
                    if (decoded != null) {
                      final resized = img.copyResize(decoded, width: 800);
                      final compressed = img.encodeJpg(resized, quality: 60);
                      setState(() {
                        _imageFile = file;
                        _imageBase64 = base64Encode(compressed);
                      });
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF32BD6C),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_showCreateProduct) {
              setState(() {
                _showCreateProduct = false;
                _showSelectSenderAddress = true;
              });
            } else if (_showSelectSenderAddress) {
              setState(() {
                _showSelectSenderAddress = false;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          "ZapGo",
          style: TextStyle(
            fontFamily: "Poppins",
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: _showCreateProduct
                      ? _buildCreateProduct()
                      : _showSelectSenderAddress
                      ? _buildSelectSenderAddress()
                      : _buildSearchReceiver(),
                ),
              ],
            ),
            if (viewInsets == 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 90,
                child: _bottomRoad(),
              ),
          ],
        ),
      ),
    );
  }

  // 🔹 หน้าแรก: ค้นหาผู้รับ
  Widget _buildSearchReceiver() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 10),
          const Text(
            "สร้างงานส่ง",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: "Roboto",
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: "ค้นหาเบอร์โทรผู้รับ",
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, color: Colors.pinkAccent),
                onPressed: _searchReceiver,
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          if (_isSearching) const CircularProgressIndicator(),
          if (_notFound)
            const Text(
              "❌ ไม่พบข้อมูลผู้รับ",
              style: TextStyle(color: Colors.red),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: _receiverAddressResult == null
                ? const SizedBox()
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 180),
                    itemCount: _receiverAddressResult!.items.length,
                    itemBuilder: (context, index) {
                      final addr = _receiverAddressResult!.items[index];
                      return Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                addr.address,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontFamily: "Roboto",
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "พิกัด: ${addr.lat}, ${addr.lng}",
                                style: const TextStyle(color: Colors.black54),
                              ),
                              const Divider(height: 20),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: () {
                                    _addressIdReceiver = addr.addressId;
                                    _fetchSenderAddresses();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.pinkAccent,
                                  ),
                                  child: const Text(
                                    "OK",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // 🔹 หน้าเลือกที่อยู่ผู้ส่ง
  Widget _buildSelectSenderAddress() {
    if (_senderAddressResult == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 180),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "เลือกที่อยู่ของผู้ส่ง",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: "Roboto",
            ),
          ),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _senderAddressResult!.items.length,
            itemBuilder: (context, index) {
              final addr = _senderAddressResult!.items[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text(addr.address),
                  trailing: Radio<int>(
                    value: index,
                    groupValue: _selectedSenderIndex,
                    onChanged: (val) {
                      setState(() {
                        _selectedSenderIndex = val;
                        _addressIdSender = addr.addressId;
                      });
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: _selectedSenderIndex == null
                  ? null
                  : () {
                      setState(() {
                        _showSelectSenderAddress = false;
                        _showCreateProduct = true;
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "ต่อไป",
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: "Roboto",
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 หน้าสร้างสินค้า
  Widget _buildCreateProduct() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("ชื่อสินค้า", style: TextStyle(fontFamily: "Roboto")),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const Text("รายละเอียด", style: TextStyle(fontFamily: "Roboto")),
            TextField(
              controller: _detailCtrl,
              maxLines: 4,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const Text("จำนวน", style: TextStyle(fontFamily: "Roboto")),
            TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.image, color: Colors.pinkAccent, size: 35),
                const SizedBox(width: 8),
                const Text("เลือกรูปภาพสินค้า"),
                const Spacer(),
                ElevatedButton(
                  onPressed: _pickImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                  ),
                  child: const Text(
                    "เลือก",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_imageFile != null)
              Center(
                child: Image.file(_imageFile!, height: 160, fit: BoxFit.cover),
              ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  final selectedAddress = _receiverAddressResult?.items
                      .firstWhere(
                        (e) => e.addressId == _addressIdReceiver,
                        orElse: () => _receiverAddressResult!.items.first,
                      );

                  final deliveryItem = sender.DeliverySenderItem(
                    id: "",
                    deliveryId: 0,
                    userIdSender: widget.userIdSender,
                    userIdReceiver: _userIdReceiver ?? 0,
                    phoneReceiver: _phoneCtrl.text.trim(),
                    addressIdSender: _addressIdSender ?? 0,
                    addressIdReceiver: _addressIdReceiver ?? 0,
                    pictureStatus1: null,
                    nameProduct: _nameCtrl.text.trim(),
                    pictureProduct: _imageBase64 ?? "No pictures",
                    detailProduct: _detailCtrl.text.trim(),
                    amount: int.tryParse(_qtyCtrl.text.trim()) ?? 1,
                    status: "waiting",

                    // ✅ ส่งชื่อและที่อยู่ผู้รับจริง
                    receiverName: _receiverName ?? "-",
                    receiverAddress: selectedAddress?.address ?? "-",
                  );

                  context.read<DeliveryProvider>().addDelivery(deliveryItem);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MainUser(userid: widget.userIdSender),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "ยืนยัน",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Footer
  Widget _bottomRoad() {
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Image.asset(
            "assets/images/img_8_cropped.png",
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          bottom: 5,
          child: Image.asset("assets/images/img_1_cropped.png", width: 150),
        ),
      ],
    );
  }
}
