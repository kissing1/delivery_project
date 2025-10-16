// To parse this JSON data, do
//
//     final accepStatusUpdateReq = accepStatusUpdateReqFromJson(jsonString);

import 'dart:convert';

AccepStatusUpdateReq accepStatusUpdateReqFromJson(String str) =>
    AccepStatusUpdateReq.fromJson(json.decode(str));

String accepStatusUpdateReqToJson(AccepStatusUpdateReq data) =>
    json.encode(data.toJson());

class AccepStatusUpdateReq {
  int deliveryId;
  int riderId;
  String pictureStatus2;
  double riderLat;
  double riderLng;

  AccepStatusUpdateReq({
    required this.deliveryId,
    required this.riderId,
    required this.pictureStatus2,
    required this.riderLat,
    required this.riderLng,
  });

  factory AccepStatusUpdateReq.fromJson(Map<String, dynamic> json) =>
      AccepStatusUpdateReq(
        deliveryId: json["delivery_id"],
        riderId: json["rider_id"],
        pictureStatus2: json["picture_status2"],
        riderLat: json["rider_lat"]?.toDouble(),
        riderLng: json["rider_lng"]?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
    "delivery_id": deliveryId,
    "rider_id": riderId,
    "picture_status2": pictureStatus2,
    "rider_lat": riderLat,
    "rider_lng": riderLng,
  };
}
