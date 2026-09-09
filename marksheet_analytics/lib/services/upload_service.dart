import 'package:dio/dio.dart';
import '../core/api_client.dart';

class UploadJobState {
  final String id;
  final String status;
  final int processed;
  final int fileCount;
  final String? errorMessage;

  UploadJobState({
    required this.id, 
    required this.status, 
    required this.processed, 
    required this.fileCount,
    this.errorMessage,
  });

  factory UploadJobState.fromJson(Map<String, dynamic> json) {
    return UploadJobState(
      id: json['id'],
      status: json['status'] ?? 'pending',
      processed: json['processed'] ?? 0,
      fileCount: json['file_count'] ?? 0,
      errorMessage: json['error_message'],
    );
  }
}

class UploadService {
  static Future<UploadJobState> uploadPdfs(String projectId, List<String> filePaths, Function(int, int) onProgress) async {
    final formData = FormData();
    for (var path in filePaths) {
      formData.files.add(MapEntry(
        'files',
        await MultipartFile.fromFile(path),
      ));
    }

    final response = await ApiClient.dio.post(
      '/upload/$projectId', 
      data: formData,
      onSendProgress: onProgress,
    );
    return UploadJobState.fromJson(response.data);
  }

  static Future<UploadJobState> checkJobStatus(String projectId, String jobId) async {
    final response = await ApiClient.dio.get('/upload/$projectId/status/$jobId');
    return UploadJobState.fromJson(response.data);
  }
}
