// To parse this JSON data, do
//
//     final deliveryCreatePostRes = deliveryCreatePostResFromJson(jsonString);

import 'dart:convert';

DeliveryCreatePostRes deliveryCreatePostResFromJson(String str) =>
    DeliveryCreatePostRes.fromJson(json.decode(str));

String deliveryCreatePostResToJson(DeliveryCreatePostRes data) =>
    json.encode(data.toJson());

class DeliveryCreatePostRes {
  bool ok;
  Delivery delivery;

  DeliveryCreatePostRes({required this.ok, required this.delivery});

  factory DeliveryCreatePostRes.fromJson(Map<String, dynamic> json) =>
      DeliveryCreatePostRes(
        ok: json["ok"],
        delivery: Delivery.fromJson(json["delivery"]),
      );

  Map<String, dynamic> toJson() => {"ok": ok, "delivery": delivery.toJson()};
}

class Delivery {
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

  // ✅ เพิ่มฟิลด์ใหม่
  String? receiverName;
  String? receiverAddress;

  Delivery({
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

  factory Delivery.fromJson(Map<String, dynamic> json) => Delivery(
    id: json["id"] ?? "",
    deliveryId: json["delivery_id"] ?? 0,
    userIdSender: json["user_id_sender"] ?? 0,
    userIdReceiver: json["user_id_receiver"] ?? 0,
    phoneReceiver: json["phone_receiver"] ?? "",
    addressIdSender: json["address_id_sender"] ?? 0,
    addressIdReceiver: json["address_id_receiver"] ?? 0,
    pictureStatus1: json["picture_status1"],
    nameProduct: json["name_product"] ?? "",
    pictureProduct: json["picture_product"] ?? "",
    detailProduct: json["detail_product"] ?? "",
    amount: json["amount"] ?? 0,
    status: json["status"] ?? "waiting",

    // ✅ เพิ่มส่วนนี้เพื่อรองรับค่าจาก backend (ถ้ามี)
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

    // ✅ เพิ่มใน toJson ด้วย
    "receiver_name": receiverName,
    "receiver_address": receiverAddress,
  };
}
