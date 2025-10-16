import 'dart:convert';

class LoginResponse {
  final String id; // UID
  final String name;
  final String phone;
  final String roleRaw; // เก็บ role เป็น string ตรง ๆ

  int get roleInt => int.tryParse(roleRaw) ?? -1;

  const LoginResponse({
    required this.id,
    required this.name,
    required this.phone,
    required this.roleRaw,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> j) => LoginResponse(
    id: j['id']?.toString() ?? '',
    name: j['name']?.toString() ?? '',
    phone: j['phone']?.toString() ?? '',
    roleRaw: j['role']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "phone": phone,
    "role": roleRaw,
  };
}
