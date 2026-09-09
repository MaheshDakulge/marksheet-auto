class AnalyticsData {
  final int totalStudents;
  final int passCount;       // FIX: was passedCount — backend sends pass_count
  final int failCount;       // FIX: was failedCount — backend sends fail_count
  final int atktCount;       // FIX: was missing — backend sends atkt_count
  final int absentCount;     // FIX: was missing
  final double avgSgpa;      // FIX: was classAverageSgpa — backend sends avg_sgpa
  final double topSgpa;      // FIX: was highestSgpa (int) — backend sends top_sgpa (double)
  final double minSgpa;      // FIX: was missing
  final int aboveAvgCount;   // FIX: was missing
  final int belowAvgCount;   // FIX: was missing
  final List<Map<String, dynamic>> toppers;
  final Map<String, dynamic> gradeDistribution;
  final List<Map<String, dynamic>> subjectAverages;
  final List<Map<String, dynamic>> sgpaHistogram;

  AnalyticsData({
    required this.totalStudents,
    required this.passCount,
    required this.failCount,
    required this.atktCount,
    required this.absentCount,
    required this.avgSgpa,
    required this.topSgpa,
    required this.minSgpa,
    required this.aboveAvgCount,
    required this.belowAvgCount,
    required this.toppers,
    required this.gradeDistribution,
    required this.subjectAverages,
    required this.sgpaHistogram,
  });

  factory AnalyticsData.fromJson(Map<String, dynamic> json) => AnalyticsData(
    totalStudents:     json['total_students']  as int? ?? 0,
    passCount:         json['pass_count']      as int? ?? 0,
    failCount:         json['fail_count']      as int? ?? 0,
    atktCount:         json['atkt_count']      as int? ?? 0,
    absentCount:       json['absent_count']    as int? ?? 0,
    avgSgpa:           double.tryParse(json['avg_sgpa']?.toString() ?? '0') ?? 0.0,
    topSgpa:           double.tryParse(json['top_sgpa']?.toString() ?? '0') ?? 0.0,
    minSgpa:           double.tryParse(json['min_sgpa']?.toString() ?? '0') ?? 0.0,
    aboveAvgCount:     json['above_avg_count'] as int? ?? 0,
    belowAvgCount:     json['below_avg_count'] as int? ?? 0,
    toppers:           (json['toppers'] as List? ?? []).cast<Map<String, dynamic>>(),
    gradeDistribution: (json['grade_distribution'] as Map?)?.cast<String, dynamic>() ?? {},
    subjectAverages:   (json['subject_averages'] as List? ?? []).cast<Map<String, dynamic>>(),
    sgpaHistogram:     (json['sgpa_histogram'] as List? ?? []).cast<Map<String, dynamic>>(),
  );
}