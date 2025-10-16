// To parse this JSON data, do
//
//     final deliverySenderPostRes = deliverySenderPostResFromJson(jsonString);

import 'dart:convert';

DeliverySenderPostRes deliverySenderPostResFromJson(String str) =>
    DeliverySenderPostRes.fromJson(json.decode(str));

String deliverySenderPostResToJson(DeliverySenderPostRes data) =>
    json.encode(data.toJson());

class DeliverySenderPostRes {
  int count;
  List<DeliverySenderItem> deliveries; // ✅ เปลี่ยนชื่อ class

  DeliverySenderPostRes({required this.count, required this.deliveries});

  factory DeliverySenderPostRes.fromJson(Map<String, dynamic> json) =>
      DeliverySenderPostRes(
        count: json["count"],
        deliveries: List<DeliverySenderItem>.from(
          json["deliveries"].map((x) => DeliverySenderItem.fromJson(x)),
        ),
      );

  Map<String, dynamic> toJson() => {
    "count": count,
    "deliveries": List<dynamic>.from(deliveries.map((x) => x.toJson())),
  };
}

class DeliverySenderItem {
  String id;
  int deliveryId;
  int userIdSender;
  int userIdReceiver;
  String phoneReceiver;
  int addressIdSender;
  int addressIdReceiver;
  dynamic pictureStatus1;
  String nameProduct;
  String pictureProduct;
  String detailProduct;
  int amount;
  String status;

  // ✅ เพิ่มสองฟิลด์นี้
  String? receiverName;
  String? receiverAddress;

  DeliverySenderItem({
    required this.id,
    required this.deliveryId,
    required this.userIdSender,
    required this.userIdReceiver,
    required this.phoneReceiver,
    required this.addressIdSender,
    required this.addressIdReceiver,
    required this.pictureStatus1,
    required this.nameProduct,
    required this.pictureProduct,
    required this.detailProduct,
    required this.amount,
    required this.status,
    this.receiverName,
    this.receiverAddress,
  });

  factory DeliverySenderItem.fromJson(Map<String, dynamic> json) =>
      DeliverySenderItem(
        id: json["id"],
        deliveryId: json["delivery_id"],
        userIdSender: json["user_id_sender"],
        userIdReceiver: json["user_id_receiver"],
        phoneReceiver: json["phone_receiver"],
        addressIdSender: json["address_id_sender"],
        addressIdReceiver: json["address_id_receiver"],
        pictureStatus1: json["picture_status1"],
        nameProduct: json["name_product"],
        pictureProduct: json["picture_product"],
        detailProduct: json["detail_product"],
        amount: json["amount"],
        status: json["status"],
        receiverName: json["receiver_name"],
        receiverAddress: json["receiver_address"],
      );

  Map<String, dynamic> toJson() => {
    "id": id,
    "delivery_id": deliveryId,
    "user_id_sender": userIdSender,
    "user_id_receiver": userIdReceiver,
    "phone_receiver": phoneReceiver,
    "address_id_sender": addressIdSender,
    "address_id_receiver": addressIdReceiver,
    "picture_status1": pictureStatus1,
    "name_product": nameProduct,
    "picture_product": pictureProduct,
    "detail_product": detailProduct,
    "amount": amount,
    "status": status,
    "receiver_name": receiverName,
    "receiver_address": receiverAddress,
  };
}
