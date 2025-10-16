// To parse this JSON data, do
//
//     final searchphonePostReq = searchphonePostReqFromJson(jsonString);

import 'dart:convert';

SearchphonePostReq searchphonePostReqFromJson(String str) =>
    SearchphonePostReq.fromJson(json.decode(str));

String searchphonePostReqToJson(SearchphonePostReq data) =>
    json.encode(data.toJson());

class SearchphonePostReq {
  String phone;

  SearchphonePostReq({required this.phone});

  factory SearchphonePostReq.fromJson(Map<String, dynamic> json) =>
      SearchphonePostReq(phone: json["phone"]);

  Map<String, dynamic> toJson() => {"phone": phone};
}
