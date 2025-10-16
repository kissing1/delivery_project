// To parse this JSON data, do
//
//     final detailDeliveryGetRes = detailDeliveryGetResFromJson(jsonString);

import 'dart:convert';

DetailDeliveryGetRes detailDeliveryGetResFromJson(String str) =>
    DetailDeliveryGetRes.fromJson(json.decode(str));

String detailDeliveryGetResToJson(DetailDeliveryGetRes data) =>
    json.encode(data.toJson());

class DetailDeliveryGetRes {
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
  Address addressSender;
  Address addressReceiver;

  DetailDeliveryGetRes({
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
    required this.addressSender,
    required this.addressReceiver,
  });

  factory DetailDeliveryGetRes.fromJson(Map<String, dynamic> json) =>
      DetailDeliveryGetRes(
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
        addressSender: Address.fromJson(json["address_sender"]),
        addressReceiver: Address.fromJson(json["address_receiver"]),
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
    "address_sender": addressSender.toJson(),
    "address_receiver": addressReceiver.toJson(),
  };
}

class Address {
  int addressId;
  int userId;
  String address;
  double lat;
  double lng;

  Address({
    required this.addressId,
    required this.userId,
    required this.address,
    required this.lat,
    required this.lng,
  });

  factory Address.fromJson(Map<String, dynamic> json) => Address(
    addressId: json["address_id"],
    userId: json["user_id"],
    address: json["address"],
    lat: json["lat"]?.toDouble(),
    lng: json["lng"]?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    "address_id": addressId,
    "user_id": userId,
    "address": address,
    "lat": lat,
    "lng": lng,
  };
}
