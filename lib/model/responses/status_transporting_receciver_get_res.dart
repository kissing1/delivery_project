// To parse this JSON data, do
//
//     final statusTransportingRececiverGetRes = statusTransportingRececiverGetResFromJson(jsonString);

import 'dart:convert';

StatusTransportingRececiverGetRes statusTransportingRececiverGetResFromJson(
  String str,
) => StatusTransportingRececiverGetRes.fromJson(json.decode(str));

String statusTransportingRececiverGetResToJson(
  StatusTransportingRececiverGetRes data,
) => json.encode(data.toJson());

class StatusTransportingRececiverGetRes {
  int userIdReceiver;
  int count;
  List<Item> items;

  StatusTransportingRececiverGetRes({
    required this.userIdReceiver,
    required this.count,
    required this.items,
  });

  factory StatusTransportingRececiverGetRes.fromJson(
    Map<String, dynamic> json,
  ) => StatusTransportingRececiverGetRes(
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
  AtedAt updatedAt;
  List<Assignment> assignments;

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
    required this.assignments,
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
    updatedAt: AtedAt.fromJson(json["updatedAt"]),
    assignments: List<Assignment>.from(
      json["assignments"].map((x) => Assignment.fromJson(x)),
    ),
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
    "updatedAt": updatedAt.toJson(),
    "assignments": List<dynamic>.from(assignments.map((x) => x.toJson())),
  };
}

class Assignment {
  String id;
  int assiId;
  int deliveryId;
  int riderId;
  dynamic pictureStatus3;
  AtedAt createdAt;
  String pictureStatus2;
  String status;
  AtedAt updatedAt;

  Assignment({
    required this.id,
    required this.assiId,
    required this.deliveryId,
    required this.riderId,
    required this.pictureStatus3,
    required this.createdAt,
    required this.pictureStatus2,
    required this.status,
    required this.updatedAt,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) => Assignment(
    id: json["id"],
    assiId: json["assi_id"],
    deliveryId: json["delivery_id"],
    riderId: json["rider_id"],
    pictureStatus3: json["picture_status3"],
    createdAt: AtedAt.fromJson(json["createdAt"]),
    pictureStatus2: json["picture_status2"],
    status: json["status"],
    updatedAt: AtedAt.fromJson(json["updatedAt"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "assi_id": assiId,
    "delivery_id": deliveryId,
    "rider_id": riderId,
    "picture_status3": pictureStatus3,
    "createdAt": createdAt.toJson(),
    "picture_status2": pictureStatus2,
    "status": status,
    "updatedAt": updatedAt.toJson(),
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
