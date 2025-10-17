// To parse this JSON data, do
//
//     final byReceiverGetRes = byReceiverGetResFromJson(jsonString);

import 'dart:convert';

ByReceiverGetRes byReceiverGetResFromJson(String str) =>
    ByReceiverGetRes.fromJson(json.decode(str));

String byReceiverGetResToJson(ByReceiverGetRes data) =>
    json.encode(data.toJson());

class ByReceiverGetRes {
  int userIdReceiver;
  int count;
  List<Item> items;

  ByReceiverGetRes({
    required this.userIdReceiver,
    required this.count,
    required this.items,
  });

  factory ByReceiverGetRes.fromJson(Map<String, dynamic> json) =>
      ByReceiverGetRes(
        userIdReceiver: json["user_id_receiver"],
        count: json["count"],
        items: List<Item>.from(json["items"].map((x) => Item.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
    "user_id_receiver": userIdReceiver,
    "count": count,
    "items": List<dynamic>.from(items.map((x) => x.toJson())),
  };
}

class Item {
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
  UpdatedAt updatedAt;

  Item({
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
    required this.updatedAt,
  });

  factory Item.fromJson(Map<String, dynamic> json) => Item(
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
    updatedAt: UpdatedAt.fromJson(json["updatedAt"]),
  );

  get assignments => null;

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
    "updatedAt": updatedAt.toJson(),
  };
}

class UpdatedAt {
  int seconds;
  int nanoseconds;

  UpdatedAt({required this.seconds, required this.nanoseconds});

  factory UpdatedAt.fromJson(Map<String, dynamic> json) =>
      UpdatedAt(seconds: json["_seconds"], nanoseconds: json["_nanoseconds"]);

  Map<String, dynamic> toJson() => {
    "_seconds": seconds,
    "_nanoseconds": nanoseconds,
  };
}
