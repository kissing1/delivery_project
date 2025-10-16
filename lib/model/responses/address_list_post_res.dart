// To parse this JSON data, do
//
//     final addressListPostRes = addressListPostResFromJson(jsonString);

import 'dart:convert';

AddressListPostRes addressListPostResFromJson(String str) =>
    AddressListPostRes.fromJson(json.decode(str));

String addressListPostResToJson(AddressListPostRes data) =>
    json.encode(data.toJson());

class AddressListPostRes {
  int count;
  List<Item> items;

  AddressListPostRes({required this.count, required this.items});

  factory AddressListPostRes.fromJson(Map<String, dynamic> json) =>
      AddressListPostRes(
        count: json["count"],
        items: List<Item>.from(json["items"].map((x) => Item.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
    "count": count,
    "items": List<dynamic>.from(items.map((x) => x.toJson())),
  };
}

class Item {
  String id;
  int addressId;
  int userId;
  String address;
  double lat;
  double lng;

  Item({
    required this.id,
    required this.addressId,
    required this.userId,
    required this.address,
    required this.lat,
    required this.lng,
  });

  factory Item.fromJson(Map<String, dynamic> json) => Item(
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
