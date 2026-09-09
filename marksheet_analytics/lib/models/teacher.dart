class Teacher {
  final String id;
  final String email;
  final String name;
  final String? college;
  final String? department;

  Teacher({
    required this.id,
    required this.email,
    required this.name,
    this.college,
    this.department,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) => Teacher(
    id:         json['id'] ?? '',
    email:      json['email'] ?? '',
    name:       json['name'] ?? '',
    college:    json['college'],
    department: json['department'],
  );
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'college': college,
    'department': department,
  };
}
