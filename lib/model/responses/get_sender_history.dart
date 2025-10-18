// To parse this JSON data, do
//
//     final getSenderHistory = getSenderHistoryFromJson(jsonString);

import 'dart:convert';

GetSenderHistory getSenderHistoryFromJson(String str) =>
    GetSenderHistory.fromJson(json.decode(str));

String getSenderHistoryToJson(GetSenderHistory data) =>
    json.encode(data.toJson());

class GetSenderHistory {
  int userIdSender;
  int count;
  List<Item> items;

  GetSenderHistory({
    required this.userIdSender,
    required this.count,
    required this.items,
  });

  factory GetSenderHistory.fromJson(Map<String, dynamic> json) =>
      GetSenderHistory(
        userIdSender: json["user_id_sender"],
        count: json["count"],
        items: List<Item>.from(json["items"].map((x) => Item.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
    "user_id_sender": userIdSender,
    "count": count,
    "items": List<dynamic>.from(items.map((x) => x.toJson())),
  };
}

class Item {
  String docId;
  int deliveryId;
  String status;
  int amount;
  int addressIdSender;
  int addressIdReceiver;
  int userIdSender;
  int userIdReceiver;
  UpdatedAt updatedAt;
  int assiId;
  int riderId;
  String pictureStatus2;
  String pictureStatus3;
  String assignmentStatus;
  UpdatedAt assignmentUpdatedAt;

  Item({
    required this.docId,
    required this.deliveryId,
    required this.status,
    required this.amount,
    required this.addressIdSender,
    required this.addressIdReceiver,
    required this.userIdSender,
    required this.userIdReceiver,
    required this.updatedAt,
    required this.assiId,
    required this.riderId,
    required this.pictureStatus2,
    required this.pictureStatus3,
    required this.assignmentStatus,
    required this.assignmentUpdatedAt,
  });

  factory Item.fromJson(Map<String, dynamic> json) => Item(
    docId: json["doc_id"],
    deliveryId: json["delivery_id"],
    status: json["status"],
    amount: json["amount"],
    addressIdSender: json["address_id_sender"],
    addressIdReceiver: json["address_id_receiver"],
    userIdSender: json["user_id_sender"],
    userIdReceiver: json["user_id_receiver"],
    updatedAt: UpdatedAt.fromJson(json["updatedAt"]),
    assiId: json["assi_id"],
    riderId: json["rider_id"],
    pictureStatus2: json["picture_status2"],
    pictureStatus3: json["picture_status3"],
    assignmentStatus: json["assignment_status"],
    assignmentUpdatedAt: UpdatedAt.fromJson(json["assignment_updatedAt"]),
  );

  Map<String, dynamic> toJson() => {
    "doc_id": docId,
    "delivery_id": deliveryId,
    "status": status,
    "amount": amount,
    "address_id_sender": addressIdSender,
    "address_id_receiver": addressIdReceiver,
    "user_id_sender": userIdSender,
    "user_id_receiver": userIdReceiver,
    "updatedAt": updatedAt.toJson(),
    "assi_id": assiId,
    "rider_id": riderId,
    "picture_status2": pictureStatus2,
    "picture_status3": pictureStatus3,
    "assignment_status": assignmentStatus,
    "assignment_updatedAt": assignmentUpdatedAt.toJson(),
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
