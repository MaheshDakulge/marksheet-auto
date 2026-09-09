/// Upload job tracking model.
/// Mirrors the backend's job status response from POST /upload/{project_id}
/// and GET /upload/{project_id}/status/{job_id}.
class UploadJob {
  final String id;
  final String projectId;
  final String status; // queued | processing | done | failed
  final int fileCount;
  final int processed;
  final String? marksheetType; // 'semester' or 'full_year'
  final String? errorMessage;

  const UploadJob({
    required this.id,
    required this.projectId,
    required this.status,
    required this.fileCount,
    required this.processed,
    this.marksheetType,
    this.errorMessage,
  });

  factory UploadJob.fromJson(Map<String, dynamic> json) {
    return UploadJob(
      id: json['id']?.toString() ?? '',
      projectId: json['project_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'queued',
      fileCount: (json['file_count'] as num?)?.toInt() ?? 0,
      processed: (json['processed'] as num?)?.toInt() ?? 0,
      marksheetType: json['marksheet_type']?.toString(),
      errorMessage: json['error_message']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_id': projectId,
        'status': status,
        'file_count': fileCount,
        'processed': processed,
        'marksheet_type': marksheetType,
        'error_message': errorMessage,
      };

  /// Progress ratio 0.0→1.0 (safe against zero division)
  double get progress => fileCount > 0 ? processed / fileCount : 0.0;

  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';
  bool get isFinished => isDone || isFailed;
}
