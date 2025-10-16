class CreateUserRequest {
  final String name;
  final String phone;
  final String password;
  final String? picture;
  final int role; // 0=user, 1=rider

  const CreateUserRequest({
    required this.name,
    required this.phone,
    required this.password,
    this.picture,
    this.role = 0,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'password': password,
    'role': role,
    if (picture != null) 'picture': picture,
  };
}
