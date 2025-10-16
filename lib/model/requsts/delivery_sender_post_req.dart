// To parse this JSON data, do
//
//     final deliverySenderPostReq = deliverySenderPostReqFromJson(jsonString);

import 'dart:convert';

DeliverySenderPostReq deliverySenderPostReqFromJson(String str) =>
    DeliverySenderPostReq.fromJson(json.decode(str));

String deliverySenderPostReqToJson(DeliverySenderPostReq data) =>
    json.encode(data.toJson());

class DeliverySenderPostReq {
  int userIdSender;

  DeliverySenderPostReq({required this.userIdSender});

  factory DeliverySenderPostReq.fromJson(Map<String, dynamic> json) =>
      DeliverySenderPostReq(userIdSender: json["user_id_sender"]);

  Map<String, dynamic> toJson() => {"user_id_sender": userIdSender};
}
