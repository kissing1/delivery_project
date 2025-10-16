// To parse this JSON data, do
//
//     final waitingDeliveriesGetRes = waitingDeliveriesGetResFromJson(jsonString);

import 'dart:convert';

List<WaitingDeliveriesGetRes> waitingDeliveriesGetResFromJson(String str) =>
    List<WaitingDeliveriesGetRes>.from(
      json.decode(str).map((x) => WaitingDeliveriesGetRes.fromJson(x)),
    );

String waitingDeliveriesGetResToJson(List<WaitingDeliveriesGetRes> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class WaitingDeliveriesGetRes {
  String id;
  int deliveryId;
  int userIdSender;
  int userIdReceiver;
  String phoneReceiver;
  int addressIdSender;
  int addressIdReceiver;
  String? pictureStatus1;
  String? nameProduct;
  String? pictureProduct;
  String detailProduct;
  int amount;
  String status;

  WaitingDeliveriesGetRes({
    required this.id,
    required this.deliveryId,
    required this.userIdSender,
    required this.userIdReceiver,
    required this.phoneReceiver,
    required this.addressIdSender,
    required this.addressIdReceiver,
    required this.pictureStatus1,
    this.nameProduct,
    this.pictureProduct,
    required this.detailProduct,
    required this.amount,
    required this.status,
  });

  factory WaitingDeliveriesGetRes.fromJson(Map<String, dynamic> json) =>
      WaitingDeliveriesGetRes(
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
  };
}
