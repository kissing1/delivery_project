class CreateAddressRequest {
  final int userId;
  final String address;
  final double lat;
  final double lng;

  const CreateAddressRequest({
    required this.userId,
    required this.address,
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'address': address,
    'lat': lat,
    'lng': lng,
  };
}
