import 'dart:convert';

DeliveryUpdateStatusReq deliveryUpdateStatusReqFromJson(String str) =>
    DeliveryUpdateStatusReq.fromJson(json.decode(str));

String deliveryUpdateStatusReqToJson(DeliveryUpdateStatusReq data) =>
    json.encode(data.toJson());

class DeliveryUpdateStatusReq {
  int deliveryId;
  String status;

  DeliveryUpdateStatusReq({required this.deliveryId, required this.status});

  factory DeliveryUpdateStatusReq.fromJson(Map<String, dynamic> json) =>
      DeliveryUpdateStatusReq(
        deliveryId: json["delivery_id"],
        status: json["status"],
      );

  Map<String, dynamic> toJson() => {
    "delivery_id": deliveryId,
    "status": status,
  };
}
