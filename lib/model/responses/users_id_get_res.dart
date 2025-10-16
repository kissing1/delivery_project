// To parse this JSON data, do
//
//     final usersIdGetRes = usersIdGetResFromJson(jsonString);

import 'dart:convert';

UsersIdGetRes usersIdGetResFromJson(String str) =>
    UsersIdGetRes.fromJson(json.decode(str));

String usersIdGetResToJson(UsersIdGetRes data) => json.encode(data.toJson());

class UsersIdGetRes {
  String id;
  int userId;
  String name;
  String password;
  String phone;
  String picture;
  int role;

  UsersIdGetRes({
    required this.id,
    required this.userId,
    required this.name,
    required this.password,
    required this.phone,
    required this.picture,
    required this.role,
  });

  factory UsersIdGetRes.fromJson(Map<String, dynamic> json) => UsersIdGetRes(
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
