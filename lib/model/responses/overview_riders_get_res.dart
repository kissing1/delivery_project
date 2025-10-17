// To parse this JSON data, do
//
//     final overviewRidersGetRes = overviewRidersGetResFromJson(jsonString);

import 'dart:convert';

OverviewRidersGetRes overviewRidersGetResFromJson(String str) =>
    OverviewRidersGetRes.fromJson(json.decode(str));

String overviewRidersGetResToJson(OverviewRidersGetRes data) =>
    json.encode(data.toJson());

class OverviewRidersGetRes {
  double riderLat;
  double riderLng;
  double receiverLat;
  double receiverLng;
  int deliveryId;
  UpdatedAt updatedAt;

  OverviewRidersGetRes({
    required this.riderLat,
    required this.riderLng,
    required this.receiverLat,
    required this.receiverLng,
    required this.deliveryId,
    required this.updatedAt,
  });

  factory OverviewRidersGetRes.fromJson(Map<String, dynamic> json) =>
      OverviewRidersGetRes(
        riderLat: json["rider_lat"]?.toDouble(),
        riderLng: json["rider_lng"]?.toDouble(),
        receiverLat: json["receiver_lat"]?.toDouble(),
        receiverLng: json["receiver_lng"]?.toDouble(),
        deliveryId: json["delivery_id"],
        updatedAt: UpdatedAt.fromJson(json["updatedAt"]),
      );

  Map<String, dynamic> toJson() => {
    "rider_lat": riderLat,
    "rider_lng": riderLng,
    "receiver_lat": receiverLat,
    "receiver_lng": receiverLng,
    "delivery_id": deliveryId,
    "updatedAt": updatedAt.toJson(),
  };
}

class UpdatedAt {
  int seconds;
  int nanoseconds;

  UpdatedAt({required this.seconds, required this.nanoseconds});

  factory UpdatedAt.fromJson(Map<String, dynamic> json) =>
      UpdatedAt(seconds: json["_seconds"], nanoseconds: json["_nanoseconds"]);

  Map<String, dynamic> toJson() => {
    "_seconds": seconds,
    "_nanoseconds": nanoseconds,
  };
}
