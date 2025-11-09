class UserProfile {
  final String? id;
  final String? name;
  final String? email;
  final String? mobile;
  final String? allergies;

  const UserProfile({
    this.id,
    this.name,
    this.email,
    this.mobile,
    this.allergies,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final dynamic rawId = json['id'] ?? json['_id'];
    return UserProfile(
      id: rawId?.toString(),
      name: json['name'] as String?,
      email: json['email'] as String?,
      mobile: json['mobile']?.toString(),
      allergies: json['allergies'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (mobile != null) 'mobile': mobile,
      if (allergies != null) 'allergies': allergies,
    };
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? mobile,
    String? allergies,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      allergies: allergies ?? this.allergies,
    );
  }

  String get allergiesDisplay {
    final value = allergies?.trim();
    return (value == null || value.isEmpty) ? "None reported" : value;
  }
}

