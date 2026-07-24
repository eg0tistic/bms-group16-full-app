class AppUser {
  final int? id;
  final String email;
  final String role;
  final String fullName;
  final bool isActive;

  const AppUser({
    this.id,
    required this.email,
    required this.role,
    required this.fullName,
    this.isActive = true,
  });

  bool get isAdmin => role == 'admin';

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
    id: map['id'] as int?,
    email: map['email'] as String,
    role: map['role'] as String,
    fullName: (map['full_name'] as String?) ?? '',
    isActive: (map['is_active'] as int? ?? 1) == 1,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'role': role,
    'full_name': fullName,
    'is_active': isActive ? 1 : 0,
  };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser.fromMap(json);
}
