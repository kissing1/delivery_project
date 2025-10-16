import 'dart:convert';

DeliveryCreatePostReq deliveryCreatePostReqFromJson(String str) =>
    DeliveryCreatePostReq.fromJson(json.decode(str));

String deliveryCreatePostReqToJson(DeliveryCreatePostReq data) =>
    json.encode(data.toJson());

class DeliveryCreatePostReq {
  int userIdSender;
  int userIdReceiver;
  String phoneReceiver;
  int addressIdSender;
  int addressIdReceiver;
  String nameProduct;
  String detailProduct;
  String pictureProduct;
  int amount;
  String status;

  DeliveryCreatePostReq({
    required this.userIdSender,
    required this.userIdReceiver,
    required this.phoneReceiver,
    required this.addressIdSender,
    required this.addressIdReceiver,
    required this.nameProduct,
    required this.detailProduct,
    required this.pictureProduct,
    required this.amount,
    required this.status,
  });

  factory DeliveryCreatePostReq.fromJson(Map<String, dynamic> json) =>
      DeliveryCreatePostReq(
        userIdSender: json["user_id_sender"],
        userIdReceiver: json["user_id_receiver"],
        phoneReceiver: json["phone_receiver"],
        addressIdSender: json["address_id_sender"],
        addressIdReceiver: json["address_id_receiver"],
        nameProduct: json["name_product"],
        detailProduct: json["detail_product"],
        pictureProduct: json["picture_product"],
        amount: json["amount"],
        status: json["status"],
      );

  Map<String, dynamic> toJson() => {
    "user_id_sender": userIdSender,
    "user_id_receiver": userIdReceiver,
    "phone_receiver": phoneReceiver,
    "address_id_sender": addressIdSender,
    "address_id_receiver": addressIdReceiver,
    "name_product": nameProduct,
    "detail_product": detailProduct,
    "picture_product": pictureProduct,
    "amount": amount,
    "status": status,
  };
}
