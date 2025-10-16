// To parse this JSON data, do
//
//     final searchphoneGetRes = searchphoneGetResFromJson(jsonString);

import 'dart:convert';

SearchphoneGetRes searchphoneGetResFromJson(String str) =>
    SearchphoneGetRes.fromJson(json.decode(str));

String searchphoneGetResToJson(SearchphoneGetRes data) =>
    json.encode(data.toJson());

class SearchphoneGetRes {
  String id;
  int userId;
  String name;
  String password;
  String phone;
  String picture;
  int role;

  SearchphoneGetRes({
    required this.id,
    required this.userId,
    required this.name,
    required this.password,
    required this.phone,
    required this.picture,
    required this.role,
  });

  factory SearchphoneGetRes.fromJson(Map<String, dynamic> json) =>
      SearchphoneGetRes(
        id: json["id"],
        userId: json["user_id"],
        name: json["name"],
        password: json["password"],
        phone: json["phone"],
        picture: json["picture"],
        role: json["role"],
      );

  Map<String, dynamic> toJson() => {
    "id": id,
    "user_id": userId,
    "name": name,
    "password": password,
    "phone": phone,
    "picture": picture,
    "role": role,
  };
}
