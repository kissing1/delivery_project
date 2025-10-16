// To parse this JSON data, do
//
//     final registerUserPostReq = registerUserPostReqFromJson(jsonString);

import 'dart:convert';

RegisterUserPostReq registerUserPostReqFromJson(String str) =>
    RegisterUserPostReq.fromJson(json.decode(str));

String registerUserPostReqToJson(RegisterUserPostReq data) =>
    json.encode(data.toJson());

class RegisterUserPostReq {
  String name;
  String phone;
  String password;
  String picture;

  RegisterUserPostReq({
    required this.name,
    required this.phone,
    required this.password,
    required this.picture,
  });

  factory RegisterUserPostReq.fromJson(Map<String, dynamic> json) =>
      RegisterUserPostReq(
        name: json["name"],
        phone: json["phone"],
        password: json["password"],
        picture: json["picture"],
      );

  Map<String, dynamic> toJson() => {
    "name": name,
    "phone": phone,
    "password": password,
    "picture": picture,
  };
}
