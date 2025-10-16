// To parse this JSON data, do
//
//     final accepStatusUpdateRes = accepStatusUpdateResFromJson(jsonString);

import 'dart:convert';

AccepStatusUpdateRes accepStatusUpdateResFromJson(String str) =>
    AccepStatusUpdateRes.fromJson(json.decode(str));

String accepStatusUpdateResToJson(AccepStatusUpdateRes data) =>
    json.encode(data.toJson());

class AccepStatusUpdateRes {
  bool ok;
  String message;
  int deliveryId;
  int assiId;
  int riderId;
  ProofImages proofImages;
  Product product;
  Meta meta;
  RiderLocation riderLocation;

  AccepStatusUpdateRes({
    required this.ok,
    required this.message,
    required this.deliveryId,
    required this.assiId,
    required this.riderId,
    required this.proofImages,
    required this.product,
    required this.meta,
    required this.riderLocation,
  });

  factory AccepStatusUpdateRes.fromJson(Map<String, dynamic> json) =>
      AccepStatusUpdateRes(
        ok: json["ok"],
        message: json["message"],
        deliveryId: json["delivery_id"],
        assiId: json["assi_id"],
        riderId: json["rider_id"],
        proofImages: ProofImages.fromJson(json["proof_images"]),
        product: Product.fromJson(json["product"]),
        meta: Meta.fromJson(json["meta"]),
        riderLocation: RiderLocation.fromJson(json["rider_location"]),
      );

  Map<String, dynamic> toJson() => {
    "ok": ok,
    "message": message,
    "delivery_id": deliveryId,
    "assi_id": assiId,
    "rider_id": riderId,
    "proof_images": proofImages.toJson(),
    "product": product.toJson(),
    "meta": meta.toJson(),
    "rider_location": riderLocation.toJson(),
  };
}

class Meta {
  String statusDelivery;
  int userIdSender;
  int userIdReceiver;
  int addressIdSender;
  int addressIdReceiver;

  Meta({
    required this.statusDelivery,
    required this.userIdSender,
    required this.userIdReceiver,
    required this.addressIdSender,
    required this.addressIdReceiver,
  });

  factory Meta.fromJson(Map<String, dynamic> json) => Meta(
    statusDelivery: json["status_delivery"],
    userIdSender: json["user_id_sender"],
    userIdReceiver: json["user_id_receiver"],
    addressIdSender: json["address_id_sender"],
    addressIdReceiver: json["address_id_receiver"],
  );

  Map<String, dynamic> toJson() => {
    "status_delivery": statusDelivery,
    "user_id_sender": userIdSender,
    "user_id_receiver": userIdReceiver,
    "address_id_sender": addressIdSender,
    "address_id_receiver": addressIdReceiver,
  };
}

class Product {
  String nameProduct;
  String detailProduct;
  String pictureProduct;
  int amount;
  String phoneReceiver;

  Product({
    required this.nameProduct,
    required this.detailProduct,
    required this.pictureProduct,
    required this.amount,
    required this.phoneReceiver,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    nameProduct: json["name_product"],
    detailProduct: json["detail_product"],
    pictureProduct: json["picture_product"],
    amount: json["amount"],
    phoneReceiver: json["phone_receiver"],
  );

  Map<String, dynamic> toJson() => {
    "name_product": nameProduct,
    "detail_product": detailProduct,
    "picture_product": pictureProduct,
    "amount": amount,
    "phone_receiver": phoneReceiver,
  };
}

class ProofImages {
  String pictureStatus2;
  dynamic pictureStatus3;

  ProofImages({required this.pictureStatus2, required this.pictureStatus3});

  factory ProofImages.fromJson(Map<String, dynamic> json) => ProofImages(
    pictureStatus2: json["picture_status2"],
    pictureStatus3: json["picture_status3"],
  );

  Map<String, dynamic> toJson() => {
    "picture_status2": pictureStatus2,
    "picture_status3": pictureStatus3,
  };
}

class RiderLocation {
  String riderLocationId;
  double lat;
  double lng;

  RiderLocation({
    required this.riderLocationId,
    required this.lat,
    required this.lng,
  });

  factory RiderLocation.fromJson(Map<String, dynamic> json) => RiderLocation(
    riderLocationId: json["rider_location_id"],
    lat: json["lat"]?.toDouble(),
    lng: json["lng"]?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    "rider_location_id": riderLocationId,
    "lat": lat,
    "lng": lng,
  };
}
