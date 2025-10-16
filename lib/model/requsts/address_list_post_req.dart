// To parse this JSON data, do
//
//     final addressListPostReq = addressListPostReqFromJson(jsonString);

import 'dart:convert';

AddressListPostReq addressListPostReqFromJson(String str) =>
    AddressListPostReq.fromJson(json.decode(str));

String addressListPostReqToJson(AddressListPostReq data) =>
    json.encode(data.toJson());

class AddressListPostReq {
  int userId;
  int limit;

  AddressListPostReq({required this.userId, required this.limit});

  factory AddressListPostReq.fromJson(Map<String, dynamic> json) =>
      AddressListPostReq(userId: json["user_id"], limit: json["limit"]);

  Map<String, dynamic> toJson() => {"user_id": userId, "limit": limit};
}
