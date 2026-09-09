class StudentResult {
  final String id;
  final String studentPrn;
  final String? studentName;  // FIX: was json['name'] — backend nests in json['students']['name']
  final String? seatNo;       // FIX: was json['seat_no'] — comes from json['students']['seat_no']
  final String? examination;
  final String? semester;
  final double? totalCredits;
  final double? totalEgp;
  final double? sgpa;
  final double? cgpa;
  final int? rank;
  final String status;
  final bool isFlagged;
  final bool isConfirmed;
  final List<String> errors;
  final List<SubjectMark> subjectMarks;

  StudentResult({
    required this.id,
    required this.studentPrn,
    this.studentName,
    this.seatNo,
    this.examination,
    this.semester,
    this.totalCredits,
    this.totalEgp,
    this.sgpa,
    this.cgpa,
    this.rank,
    this.status = 'pending',
    this.isFlagged = false,
    this.isConfirmed = false,
    this.errors = const [],
    required this.subjectMarks,
  });

  factory StudentResult.fromJson(Map<String, dynamic> json) {
    // FIX: backend returns student info nested under 'students' key
    final student = json['students'] as Map<String, dynamic>? ?? {};

    return StudentResult(
      id:           json['id']?.toString() ?? '',
      studentPrn:   json['student_prn']?.toString() ?? '',
      studentName:  student['name']?.toString() ?? json['name']?.toString(),
      seatNo:       student['seat_no']?.toString() ?? json['seat_no']?.toString(),
      examination:  json['examination']?.toString(),
      semester:     json['semester']?.toString(),
      totalCredits: double.tryParse(json['total_credits']?.toString() ?? ''),
      totalEgp:     double.tryParse(json['total_egp']?.toString() ?? ''),
      sgpa:         double.tryParse(json['sgpa']?.toString() ?? ''),
      cgpa:         double.tryParse(json['cgpa']?.toString() ?? ''),
      rank:         json['rank'] as int?,
      status:       json['status']?.toString() ?? 'pending',
      isFlagged:    json['is_flagged'] as bool? ?? false,
      isConfirmed:  json['is_confirmed'] as bool? ?? false,
      errors:       (json['errors'] as List? ?? []).map((e) => e.toString()).toList(),
      subjectMarks: (json['subject_marks'] as List? ?? [])
          .map((m) => SubjectMark.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SubjectMark {
  final String id;
  final int? srNo;
  final String? courseCode;
  final String? courseName;
  final double? credits;
  final String? gradeObtained;
  final double? gradePoint;
  final double? earnedGp;
  final String? remark;

  SubjectMark({
    required this.id,
    this.srNo,
    this.courseCode,
    this.courseName,
    this.credits,
    this.gradeObtained,
    this.gradePoint,
    this.earnedGp,
    this.remark,
  });

  factory SubjectMark.fromJson(Map<String, dynamic> json) => SubjectMark(
    id:            json['id']?.toString() ?? '',
    srNo:          json['sr_no'] as int?,
    courseCode:    json['course_code']?.toString(),
    courseName:    json['course_name']?.toString(),
    credits:       double.tryParse(json['credits']?.toString() ?? ''),
    gradeObtained: json['grade_obtained']?.toString(),
    gradePoint:    double.tryParse(json['grade_point']?.toString() ?? ''),
    earnedGp:      double.tryParse(json['earned_gp']?.toString() ?? ''),
    remark:        json['remark']?.toString(),
  );
}