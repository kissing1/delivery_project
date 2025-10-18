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
  // --------- Controllers ----------
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _detailCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();

  // --------- Form / Validators ----------
  final _formKey = GlobalKey<FormState>();
  String? _requiredValidator(String? v, {String label = 'จำเป็นต้องกรอก'}) {
    if (v == null || v.trim().isEmpty) return label;
    return null;
  }

  String? _qtyValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'ใส่จำนวน';
    final n = int.tryParse(v.trim());
    if (n == null || n <= 0) return 'จำนวนต้องเป็นเลขมากกว่า 0';
    return null;
  }

  // --------- State ----------
  final ImagePicker _picker = ImagePicker();
  String? _apiBase;
  bool _isSearching = false;
  bool _notFound = false;

  int? _userIdReceiver;
  int? _addressIdReceiver;
  int? _addressIdSender;
  int? _selectedSenderIndex;

  String? _receiverName;
  AddressListPostRes? _receiverAddressResult;
  AddressListPostRes? _senderAddressResult;

  File? _imageFile;
  String? _imageBase64;

  bool _showSelectSenderAddress = false;
  bool _showCreateProduct = false;

  // ✅ เล่นแอนิเมชัน footer แค่ครั้งเดียว
  bool _footerAnimatedOnce = false;

  // --------- Theming ----------
  static const kGreen = Color(0xFF32BD6C);
  static const kGreenDark = Color(0xFF249B58);
  static const kPink = Color(0xFFFF5C8A);

  // --------- Derived Flags ----------
  bool get _isReadyReceiver =>
      _userIdReceiver != null && _addressIdReceiver != null;
  bool get _isReadySender => _addressIdSender != null;
  bool get _isCreateFormFilled {
    final okName = _nameCtrl.text.trim().isNotEmpty;
    final okDetail = _detailCtrl.text.trim().isNotEmpty;
    final qtyStr = _qtyCtrl.text.trim();
    final okQty = int.tryParse(qtyStr) != null && int.parse(qtyStr) > 0;
    final okImage = _imageBase64 != null && _imageBase64!.isNotEmpty;
    return okName && okDetail && okQty && okImage;
  }

  bool get _canSubmit =>
      _isReadyReceiver && _isReadySender && _isCreateFormFilled;

  void _onAnyFieldChanged() {
    if (mounted) setState(() {});
  }

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

  // --------- API: ค้นหาเบอร์ผู้รับ ----------
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
        _receiverName = user.name;

        // ดึงที่อยู่ผู้รับ
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

  // --------- API: ที่อยู่ผู้ส่ง ----------
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

  // --------- เลือกรูป ----------
  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_camera, color: kGreen),
                title: const Text(
                  "ถ่ายรูปด้วยกล้อง",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
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
                      _onAnyFieldChanged();
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: kPink),
                title: const Text(
                  "เลือกจากแกลเลอรี",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
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
                      _onAnyFieldChanged();
                    }
                  }
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // --------- UI ----------
  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kGreen, kGreenDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _stepHeader(),
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // ใช้ AnimatedSwitcher เพื่อทรานซิชันระหว่างหน้าต่างๆ
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: anim.drive(
                    Tween<Offset>(
                      begin: const Offset(0, .06),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutCubic)),
                  ),
                  child: child,
                ),
              ),
              child: _showCreateProduct
                  ? _buildCreateProduct(key: const ValueKey('create'))
                  : _showSelectSenderAddress
                  ? _buildSelectSenderAddress(key: const ValueKey('sender'))
                  : _buildSearchReceiver(key: const ValueKey('search')),
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

  // ---- Header แสดงสเต็ป ----
  Widget _stepHeader() {
    final step = _showCreateProduct ? 3 : (_showSelectSenderAddress ? 2 : 1);

    Widget dot(int i, String label) {
      final active = i == step;
      final passed = i < step;
      final color = passed ? kGreen : (active ? kPink : Colors.black26);

      return Expanded(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 6,
                    decoration: BoxDecoration(
                      color: (i == 1)
                          ? color
                          : (passed || active)
                          ? color
                          : Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: active ? 12 : 10,
                  backgroundColor: color,
                  child: Text(
                    "$i",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? Colors.black87 : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        dot(1, "ค้นหาผู้รับ"),
        dot(2, "เลือกที่อยู่ผู้ส่ง"),
        dot(3, "กรอกสินค้า"),
      ],
    );
  }

  // ---- หน้า: ค้นหาผู้รับ ----
  Widget _buildSearchReceiver({Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("สร้างงานส่ง"),
          const SizedBox(height: 10),
          _themedField(
            controller: _phoneCtrl,
            label: "ค้นหาเบอร์โทรผู้รับ",
            hint: "กรอกเบอร์โทร เช่น 089xxxxxxx",
            icon: Icons.phone_iphone,
            actionIcon: Icons.search,
            onAction: _searchReceiver,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          if (_isSearching) const Center(child: CircularProgressIndicator()),
          if (_notFound)
            const Center(
              child: Text(
                "❌ ไม่พบข้อมูลผู้รับ",
                style: TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 8),

          // รายการที่อยู่ผู้รับ
          Expanded(
            child: _receiverAddressResult == null
                ? const SizedBox()
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 6),
                    itemCount: _receiverAddressResult!.items.length,
                    itemBuilder: (context, index) {
                      final addr = _receiverAddressResult!.items[index];
                      return _animatedCard(
                        index: index,
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              _addressIdReceiver = addr.addressId;
                              _fetchSenderAddresses();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: kGreen.withOpacity(.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.location_on,
                                      color: kGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          addr.address,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "พิกัด: ${addr.lat}, ${addr.lng}",
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Colors.black26,
                                  ),
                                ],
                              ),
                            ),
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

  // ---- หน้า: เลือกที่อยู่ผู้ส่ง ----
  Widget _buildSelectSenderAddress({Key? key}) {
    if (_senderAddressResult == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("เลือกที่อยู่ของผู้ส่ง"),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _senderAddressResult!.items.length,
            itemBuilder: (context, index) {
              final addr = _senderAddressResult!.items[index];
              return _animatedCard(
                index: index,
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: RadioListTile<int>(
                    controlAffinity: ListTileControlAffinity.trailing,
                    value: index,
                    groupValue: _selectedSenderIndex,
                    onChanged: (val) {
                      setState(() {
                        _selectedSenderIndex = val;
                        _addressIdSender = addr.addressId;
                      });
                    },
                    title: Text(addr.address),
                    activeColor: kPink,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Center(
            child: _primaryButton(
              label: "ต่อไป",
              enabled: _selectedSenderIndex != null,
              onPressed: _selectedSenderIndex == null
                  ? null
                  : () {
                      setState(() {
                        _showSelectSenderAddress = false;
                        _showCreateProduct = true;
                      });
                    },
            ),
          ),
        ],
      ),
    );
  }

  // ---- หน้า: กรอกรายละเอียดสินค้า ----
  Widget _buildCreateProduct({Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: _animatedCard(
            index: 0,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle("รายละเอียดสินค้า"),
                    const SizedBox(height: 10),

                    _themedField(
                      controller: _nameCtrl,
                      label: "ชื่อสินค้า",
                      hint: "เช่น กล่องขนม, เอกสารสำคัญ",
                      icon: Icons.inventory_2,
                      validator: (v) =>
                          _requiredValidator(v, label: 'กรอกชื่อสินค้า'),
                      onChanged: (_) => _onAnyFieldChanged(),
                    ),
                    const SizedBox(height: 12),

                    _themedField(
                      controller: _detailCtrl,
                      label: "รายละเอียด",
                      hint: "อธิบายสั้นๆ เกี่ยวกับสินค้า",
                      icon: Icons.description,
                      maxLines: 4,
                      validator: (v) =>
                          _requiredValidator(v, label: 'กรอกรายละเอียด'),
                      onChanged: (_) => _onAnyFieldChanged(),
                    ),
                    const SizedBox(height: 12),

                    _themedField(
                      controller: _qtyCtrl,
                      label: "จำนวน",
                      hint: "ตัวเลขมากกว่า 0",
                      icon: Icons.numbers,
                      keyboardType: TextInputType.number,
                      validator: _qtyValidator,
                      onChanged: (_) => _onAnyFieldChanged(),
                    ),
                    const SizedBox(height: 16),

                    Text("รูปภาพสินค้า", style: _labelStyle()),
                    const SizedBox(height: 8),
                    _imagePickerTile(),

                    if (_imageFile != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _imageFile!,
                          height: 170,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),
                    _statusBar(),

                    const SizedBox(height: 18),
                    Center(
                      child: _primaryButton(
                        label: "ยืนยัน",
                        enabled: _canSubmit,
                        onPressed: !_canSubmit
                            ? null
                            : () {
                                final ok =
                                    _formKey.currentState?.validate() ?? false;
                                if (!ok) return;

                                if (!_isReadyReceiver) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'เลือกผู้รับและที่อยู่ผู้รับก่อน',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                if (!_isReadySender) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('เลือกที่อยู่ผู้ส่งก่อน'),
                                    ),
                                  );
                                  return;
                                }
                                if (_imageBase64 == null ||
                                    _imageBase64!.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('แนบรูปสินค้าก่อน'),
                                    ),
                                  );
                                  return;
                                }

                                final selectedAddress = _receiverAddressResult
                                    ?.items
                                    .firstWhere(
                                      (e) => e.addressId == _addressIdReceiver,
                                      orElse: () =>
                                          _receiverAddressResult!.items.first,
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
                                  amount:
                                      int.tryParse(_qtyCtrl.text.trim()) ?? 1,
                                  status: "waiting",
                                  receiverName: _receiverName ?? "-",
                                  receiverAddress:
                                      selectedAddress?.address ?? "-",
                                );

                                context.read<DeliveryProvider>().addDelivery(
                                  deliveryItem,
                                );

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        MainUser(userid: widget.userIdSender),
                                  ),
                                );
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---- Widgets ช่วยตกแต่ง ----
  Text _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      color: Colors.black87,
    ),
  );

  TextStyle _labelStyle() =>
      const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87);

  Widget _themedField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    IconData? actionIcon,
    VoidCallback? onAction,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: kGreen),
        suffixIcon: (actionIcon != null)
            ? IconButton(
                icon: Icon(actionIcon, color: kPink),
                onPressed: onAction,
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black12.withOpacity(.15)),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: kGreen, width: 1.4),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _imagePickerTile() {
    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: kGreen.withOpacity(.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kGreen.withOpacity(.25)),
        ),
        child: Row(
          children: const [
            Icon(Icons.add_a_photo, color: kGreen),
            SizedBox(width: 10),
            Text(
              "แตะเพื่อเลือกรูปภาพ",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Spacer(),
            Icon(Icons.chevron_right, color: Colors.black38),
          ],
        ),
      ),
    );
  }

  Widget _statusBar() {
    final ok1 = _isReadyReceiver;
    final ok2 = _isReadySender;
    final ok3 = _imageBase64 != null && _imageBase64!.isNotEmpty;

    Chip chip(String t, bool ok) {
      return Chip(
        avatar: CircleAvatar(
          backgroundColor: ok ? kGreen : Colors.black12,
          child: Icon(
            ok ? Icons.check : Icons.hourglass_bottom,
            size: 14,
            color: Colors.white,
          ),
        ),
        label: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: ok
            ? kGreen.withOpacity(.10)
            : Colors.black12.withOpacity(.08),
        side: BorderSide(color: ok ? kGreen.withOpacity(.6) : Colors.black12),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: -4,
      children: [
        chip("เลือกผู้รับ", ok1),
        chip("ที่อยู่ผู้ส่ง", ok2),
        chip("แนบรูป", ok3),
      ],
    );
  }

  Widget _primaryButton({
    required String label,
    required bool enabled,
    VoidCallback? onPressed,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: enabled ? 0.96 : 1.0, end: enabled ? 1.0 : 1.0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPink,
          disabledBackgroundColor: Colors.black26,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: enabled ? 4 : 0,
          shadowColor: kPink.withOpacity(.35),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _animatedCard({required int index, required Widget child}) {
    final dur = 260 + (index * 60);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: dur),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - v)),
          child: child,
        ),
      ),
    );
  }

  // ✅ Footer (ถนน + รถ) เล่นครั้งเดียว
  Widget _bottomRoad() {
    final beginScale = _footerAnimatedOnce ? 1.0 : 0.94;
    final dur = _footerAnimatedOnce
        ? Duration.zero
        : const Duration(milliseconds: 600);

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
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: beginScale, end: 1.0),
            duration: dur,
            curve: Curves.easeOutBack,
            onEnd: () {
              if (!_footerAnimatedOnce) {
                setState(() => _footerAnimatedOnce = true);
              }
            },
            builder: (context, v, child) =>
                Transform.scale(scale: v, child: child),
            child: Image.asset("assets/images/img_1_cropped.png", width: 150),
          ),
        ),
      ],
    );
  }
}
