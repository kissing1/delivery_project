// To parse this JSON data, do
//
//     final usersAddressIdGetRes = usersAddressIdGetResFromJson(jsonString);

import 'dart:convert';

UsersAddressIdGetRes usersAddressIdGetResFromJson(String str) =>
    UsersAddressIdGetRes.fromJson(json.decode(str));

String usersAddressIdGetResToJson(UsersAddressIdGetRes data) =>
    json.encode(data.toJson());

class UsersAddressIdGetRes {
  String id;
  int addressId;
  int userId;
  String address;
  double lat;
  double lng;

  UsersAddressIdGetRes({
    required this.id,
    required this.addressId,
    required this.userId,
    required this.address,
    required this.lat,
    required this.lng,
  });

  factory UsersAddressIdGetRes.fromJson(Map<String, dynamic> json) =>
      UsersAddressIdGetRes(
        id: json["id"],
        addressId: json["address_id"],
        userId: json["user_id"],
        address: json["address"],
        lat: json["lat"]?.toDouble(),
        lng: json["lng"]?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
    "id": id,
    "address_id": addressId,
    "user_id": userId,
    "address": address,
    "lat": lat,
    "lng": lng,
  };
}
