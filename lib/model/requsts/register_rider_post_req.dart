// To parse this JSON data, do
//
//     final registerRiderPostReq = registerRiderPostReqFromJson(jsonString);

import 'dart:convert';

RegisterRiderPostReq registerRiderPostReqFromJson(String str) =>
    RegisterRiderPostReq.fromJson(json.decode(str));

String registerRiderPostReqToJson(RegisterRiderPostReq data) =>
    json.encode(data.toJson());

class RegisterRiderPostReq {
  String name;
  String phone;
  String password;
  String picture;
  String imageCar;
  String plateNumber;
  String carType;

  RegisterRiderPostReq({
    required this.name,
    required this.phone,
    required this.password,
    required this.picture,
    required this.imageCar,
    required this.plateNumber,
    required this.carType,
  });

  factory RegisterRiderPostReq.fromJson(Map<String, dynamic> json) =>
      RegisterRiderPostReq(
        name: json["name"],
        phone: json["phone"],
        password: json["password"],
        picture: json["picture"],
        imageCar: json["image_car"],
        plateNumber: json["plate_number"],
        carType: json["car_type"],
      );

  Map<String, dynamic> toJson() => {
    "name": name,
    "phone": phone,
    "password": password,
    "picture": picture,
    "image_car": imageCar,
    "plate_number": plateNumber,
    "car_type": carType,
  };
}
