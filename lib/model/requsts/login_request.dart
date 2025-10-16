import 'dart:convert';

class LoginRequest {
  final String phone;
  final String password;

  const LoginRequest({required this.phone, required this.password});

  Map<String, dynamic> toJson() => {'phone': phone, 'password': password};
}

String loginRequestToJson(LoginRequest r) => jsonEncode(r.toJson());
