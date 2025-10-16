import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/model/responses/DElivery_sender_post_res.dart';

class DeliveryProvider extends ChangeNotifier {
  // ✅ ใช้ List<Delivery> แทน Map<String, dynamic>
  final List<DeliverySenderItem> _deliveries = [];

  // ✅ getter สำหรับอ่านข้อมูล
  List<DeliverySenderItem> get deliveries => _deliveries;

  // ✅ เพิ่มข้อมูลใหม่ (จาก model Delivery)
  void addDelivery(DeliverySenderItem data) {
    _deliveries.add(data);
    notifyListeners();
  }

  // ✅ เซ็ตข้อมูลใหม่ทั้งหมด (ใช้หลังโหลดจาก API)
  void setDeliveries(List<DeliverySenderItem> newDeliveries) {
    _deliveries
      ..clear()
      ..addAll(newDeliveries);
    notifyListeners();
  }

  // ✅ ลบข้อมูลทั้งหมด
  void clearAll() {
    _deliveries.clear();
    notifyListeners();
  }

  // ✅ ลบตามลำดับ index
  void removeAt(int index) {
    _deliveries.removeAt(index);
    notifyListeners();
  }

  // ✅ ลบตาม ID (ใช้ตอนลบแต่ละรายการ)
  void removeDeliveryById(dynamic id) {
    _deliveries.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  // ✅ อีกชื่อหนึ่งของ clearAll (สำหรับเรียกจากหน้าอื่น)
  void clear() {
    _deliveries.clear();
    notifyListeners();
  }
}
