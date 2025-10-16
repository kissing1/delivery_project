// To parse this JSON data, do
//
//     final ridercarGetRes = ridercarGetResFromJson(jsonString);

import 'dart:convert';

RidercarGetRes ridercarGetResFromJson(String str) =>
    RidercarGetRes.fromJson(json.decode(str));

String ridercarGetResToJson(RidercarGetRes data) => json.encode(data.toJson());

class RidercarGetRes {
  String id;
  int riderId;
  int userId;
  String imageCar;
  String plateNumber;
  String carType;

  RidercarGetRes({
    required this.id,
    required this.riderId,
    required this.userId,
    required this.imageCar,
    required this.plateNumber,
    required this.carType,
  });

  factory RidercarGetRes.fromJson(Map<String, dynamic> json) => RidercarGetRes(
    id: json["id"],
    riderId: json["rider_id"],
    userId: json["user_id"],
    imageCar: json["image_car"],
    plateNumber: json["plate_number"],
    carType: json["car_type"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "rider_id": riderId,
    "user_id": userId,
    "image_car": imageCar,
    "plate_number": plateNumber,
    "car_type": carType,
  };
}
