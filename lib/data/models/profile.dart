class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.phone,
    this.contactEmail,
    this.timezone,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? phone;
  final String? contactEmail;
  final String? timezone;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? 'Family Member',
      avatarUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      contactEmail: json['contact_email'] as String?,
      timezone: json['timezone'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'phone': phone,
        'contact_email': contactEmail,
        'timezone': timezone,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
