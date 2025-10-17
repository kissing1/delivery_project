// To parse this JSON data, do
//
//     final overviewRiderGetRes = overviewRiderGetResFromJson(jsonString);

import 'dart:convert';

OverviewRiderGetRes overviewRiderGetResFromJson(String str) =>
    OverviewRiderGetRes.fromJson(json.decode(str));

String overviewRiderGetResToJson(OverviewRiderGetRes data) =>
    json.encode(data.toJson());

class OverviewRiderGetRes {
  double riderLat;
  double riderLng;
  dynamic receiverLat;
  dynamic receiverLng;
  dynamic deliveryId;
  UpdatedAt updatedAt;

  OverviewRiderGetRes({
    required this.riderLat,
    required this.riderLng,
    required this.receiverLat,
    required this.receiverLng,
    required this.deliveryId,
    required this.updatedAt,
  });

  factory OverviewRiderGetRes.fromJson(Map<String, dynamic> json) =>
      OverviewRiderGetRes(
        riderLat: json["rider_lat"]?.toDouble(),
        riderLng: json["rider_lng"]?.toDouble(),
        receiverLat: json["receiver_lat"],
        receiverLng: json["receiver_lng"],
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
