class AddressItem {
  final String addressId; // doc id
  final String userId;
  final String address;
  final String? lat;
  final String? lng;

  AddressItem({
    required this.addressId,
    required this.userId,
    required this.address,
    this.lat,
    this.lng,
  });

  factory AddressItem.fromJson(Map<String, dynamic> j) => AddressItem(
    addressId: (j['address_id'] ?? j['id'] ?? '') as String,
    userId: (j['user_id'] ?? '') as String,
    address: (j['address'] ?? '') as String,
    lat: j['lat'] == null ? null : (j['lat'] as num).toString(),
    lng: j['lng'] == null ? null : (j['lng'] as num).toString(),
  );

  Map<String, dynamic> toJson() => {
    'address_id': addressId,
    'user_id': userId,
    'address': address,
    'lat': lat,
    'lng': lng,
  };
}
