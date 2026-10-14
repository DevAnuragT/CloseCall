import 'package:meta/meta.dart';

/// An authenticated CloseCall user. Backed by the auth provider; the `id` is
/// the stable identity used as a foreign key across Supabase tables.
@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    this.email,
    this.photoUrl,
  });

  final String id;
  final String displayName;
  final String? email;
  final String? photoUrl;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      email: json['email'] as String?,
      photoUrl: json['photo_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'display_name': displayName,
    'email': email,
    'photo_url': photoUrl,
  };

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.id == id &&
      other.displayName == displayName &&
      other.email == email &&
      other.photoUrl == photoUrl;

  @override
  int get hashCode => Object.hash(id, displayName, email, photoUrl);
}
