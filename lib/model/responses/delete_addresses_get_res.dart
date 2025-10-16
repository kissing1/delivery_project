import 'dart:convert';

DeleteAddressesGetRes deleteAddressesGetResFromJson(String str) =>
    DeleteAddressesGetRes.fromJson(json.decode(str));

String deleteAddressesGetResToJson(DeleteAddressesGetRes data) =>
    json.encode(data.toJson());

class DeleteAddressesGetRes {
  bool ok;
  String message;

  DeleteAddressesGetRes({required this.ok, required this.message});

  factory DeleteAddressesGetRes.fromJson(Map<String, dynamic> json) =>
      DeleteAddressesGetRes(ok: json["ok"], message: json["message"]);

  Map<String, dynamic> toJson() => {"ok": ok, "message": message};
}
