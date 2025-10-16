// To parse this JSON data, do
//
//     final addAddressPostReq = addAddressPostReqFromJson(jsonString);

import 'dart:convert';

AddAddressPostReq addAddressPostReqFromJson(String str) =>
    AddAddressPostReq.fromJson(json.decode(str));

String addAddressPostReqToJson(AddAddressPostReq data) =>
    json.encode(data.toJson());

class AddAddressPostReq {
  int userId;
  String address;
  double lat;
  double lng;

  AddAddressPostReq({
    required this.userId,
    required this.address,
    required this.lat,
    required this.lng,
  });

  factory AddAddressPostReq.fromJson(Map<String, dynamic> json) =>
      AddAddressPostReq(
        userId: json["user_id"],
        address: json["address"],
        lat: json["lat"]?.toDouble(),
        lng: json["lng"]?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
    "user_id": userId,
    "address": address,
    "lat": lat,
    "lng": lng,
  };
}
