class Project {
  final String id;
  final String name;
  final String? program;
  final String? examination;
  final String? semester;
  final int passingMarks;
  final String projectType;
  final String status;
  final String teacherId;
  final DateTime? createdAt;

  Project({
    required this.id,
    required this.name,
    this.program,
    this.examination,
    this.semester,
    this.passingMarks = 40,
    this.projectType = 'semester',
    required this.status,
    required this.teacherId,
    this.createdAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) => Project(
    id:           json['id'],
    name:         json['name'],
    program:      json['program'],
    examination:  json['examination'],
    semester:     json['semester'],
    passingMarks: json['passing_marks'] ?? 40,
    projectType:  json['project_type'] ?? 'semester',
    status:       json['status'] ?? 'created',
    teacherId:    json['teacher_id'],
    createdAt:    json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
  );

  bool get isSemester  => projectType == 'semester';
  bool get isFullYear  => projectType == 'full_year';
  String get typeLabel => isFullYear ? 'Full Year' : 'Single Semester';
}
