import 'dart:convert';

DeleteAddressesPostReq deleteAddressesPostReqFromJson(String str) =>
    DeleteAddressesPostReq.fromJson(json.decode(str));

String deleteAddressesPostReqToJson(DeleteAddressesPostReq data) =>
    json.encode(data.toJson());

class DeleteAddressesPostReq {
  int userId;
  String addressId;

  DeleteAddressesPostReq({required this.userId, required this.addressId});

  factory DeleteAddressesPostReq.fromJson(Map<String, dynamic> json) =>
      DeleteAddressesPostReq(
        userId: json["user_id"],
        addressId: json["address_id"],
      );

  Map<String, dynamic> toJson() => {"user_id": userId, "address_id": addressId};
}
