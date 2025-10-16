class UserItem {
  final String id; // UID เป็นสตริง
  final String name;
  final String phone;
  final int role; // แปลงจาก "1" → 1

  const UserItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
  });

  factory UserItem.fromLoginJson(Map<String, dynamic> j) => UserItem(
    id: j['id']?.toString() ?? '',
    name: j['name']?.toString() ?? '',
    phone: j['phone']?.toString() ?? '',
    role: int.tryParse(j['role']?.toString() ?? '') ?? -1,
  );
}
