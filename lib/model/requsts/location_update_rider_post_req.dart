// To parse this JSON data, do
//
//     final locationUpdateRiderPostReq = locationUpdateRiderPostReqFromJson(jsonString);

import 'dart:convert';

LocationUpdateRiderPostReq locationUpdateRiderPostReqFromJson(String str) =>
    LocationUpdateRiderPostReq.fromJson(json.decode(str));

String locationUpdateRiderPostReqToJson(LocationUpdateRiderPostReq data) =>
    json.encode(data.toJson());

class LocationUpdateRiderPostReq {
  int riderId;
  double lat;
  double lng;
  int riderLocationId;

  LocationUpdateRiderPostReq({
    required this.riderId,
    required this.lat,
    required this.lng,
    required this.riderLocationId,
  });

  factory LocationUpdateRiderPostReq.fromJson(Map<String, dynamic> json) =>
      LocationUpdateRiderPostReq(
        riderId: json["rider_id"],
        lat: json["lat"]?.toDouble(),
        lng: json["lng"]?.toDouble(),
        riderLocationId: json["rider_location_id"],
      );

  Map<String, dynamic> toJson() => {
    "rider_id": riderId,
    "lat": lat,
    "lng": lng,
    "rider_location_id": riderLocationId,
  };
}
