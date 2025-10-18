// To parse this JSON data, do
//
//     final historyRidersGetRes = historyRidersGetResFromJson(jsonString);

import 'dart:convert';

HistoryRidersGetRes historyRidersGetResFromJson(String str) =>
    HistoryRidersGetRes.fromJson(json.decode(str));

String historyRidersGetResToJson(HistoryRidersGetRes data) =>
    json.encode(data.toJson());

class HistoryRidersGetRes {
  int role;
  int count;
  List<Item> items;

  HistoryRidersGetRes({
    required this.role,
    required this.count,
    required this.items,
  });

  factory HistoryRidersGetRes.fromJson(Map<String, dynamic> json) =>
      HistoryRidersGetRes(
        role: json["role"],
        count: json["count"],
        items: List<Item>.from(json["items"].map((x) => Item.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
    "role": role,
    "count": count,
    "items": List<dynamic>.from(items.map((x) => x.toJson())),
  };
}

class Item {
  int assiId;
  String id;
  int riderId;
  int deliveryId;
  String status;
  String pictureStatus2;
  String pictureStatus3;
  AtedAt createdAt;
  AtedAt updatedAt;
  Delivery delivery;

  Item({
    required this.assiId,
    required this.id,
    required this.riderId,
    required this.deliveryId,
    required this.status,
    required this.pictureStatus2,
    required this.pictureStatus3,
    required this.createdAt,
    required this.updatedAt,
    required this.delivery,
  });

  factory Item.fromJson(Map<String, dynamic> json) => Item(
    assiId: json["assi_id"],
    id: json["id"],
    riderId: json["rider_id"],
    deliveryId: json["delivery_id"],
    status: json["status"],
    pictureStatus2: json["picture_status2"],
    pictureStatus3: json["picture_status3"],
    createdAt: AtedAt.fromJson(json["createdAt"]),
    updatedAt: AtedAt.fromJson(json["updatedAt"]),
    delivery: Delivery.fromJson(json["delivery"]),
  );

  Map<String, dynamic> toJson() => {
    "assi_id": assiId,
    "id": id,
    "rider_id": riderId,
    "delivery_id": deliveryId,
    "status": status,
    "picture_status2": pictureStatus2,
    "picture_status3": pictureStatus3,
    "createdAt": createdAt.toJson(),
    "updatedAt": updatedAt.toJson(),
    "delivery": delivery.toJson(),
  };
}

class AtedAt {
  int seconds;
  int nanoseconds;

  AtedAt({required this.seconds, required this.nanoseconds});

  factory AtedAt.fromJson(Map<String, dynamic> json) =>
      AtedAt(seconds: json["_seconds"], nanoseconds: json["_nanoseconds"]);

  Map<String, dynamic> toJson() => {
    "_seconds": seconds,
    "_nanoseconds": nanoseconds,
  };
}

class Delivery {
  String id;
  int userIdSender;
  int userIdReceiver;
  int addressIdSender;
  int addressIdReceiver;
  String nameProduct;
  String detailProduct;
  int amount;
  String pictureProduct;
  dynamic pictureStatus1;
  String phoneReceiver;
  String status;
  AtedAt updatedAt;

  Delivery({
    required this.id,
    required this.userIdSender,
    required this.userIdReceiver,
    required this.addressIdSender,
    required this.addressIdReceiver,
    required this.nameProduct,
    required this.detailProduct,
    required this.amount,
    required this.pictureProduct,
    required this.pictureStatus1,
    required this.phoneReceiver,
    required this.status,
    required this.updatedAt,
  });

  factory Delivery.fromJson(Map<String, dynamic> json) => Delivery(
    id: json["id"],
    userIdSender: json["user_id_sender"],
    userIdReceiver: json["user_id_receiver"],
    addressIdSender: json["address_id_sender"],
    addressIdReceiver: json["address_id_receiver"],
    nameProduct: json["name_product"],
    detailProduct: json["detail_product"],
    amount: json["amount"],
    pictureProduct: json["picture_product"],
    pictureStatus1: json["picture_status1"],
    phoneReceiver: json["phone_receiver"],
    status: json["status"],
    updatedAt: AtedAt.fromJson(json["updatedAt"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "user_id_sender": userIdSender,
    "user_id_receiver": userIdReceiver,
    "address_id_sender": addressIdSender,
    "address_id_receiver": addressIdReceiver,
    "name_product": nameProduct,
    "detail_product": detailProduct,
    "amount": amount,
    "picture_product": pictureProduct,
    "picture_status1": pictureStatus1,
    "phone_receiver": phoneReceiver,
    "status": status,
    "updatedAt": updatedAt.toJson(),
  };
}
