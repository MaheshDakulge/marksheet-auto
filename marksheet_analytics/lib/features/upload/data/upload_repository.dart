import 'dart:async';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/api_client.dart';
import '../domain/upload_job_model.dart';

class UploadRepository {
  final Dio _dio;

  UploadRepository({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  /// Upload multiple PDFs at once for a project.
  /// Returns the job object from the server.
  Future<UploadJob> uploadFiles(
    String projectId,
    List<PlatformFile> files, {
    String? templateId,
  }) async {
    final formData = FormData();
    for (final file in files) {
      if (file.bytes != null) {
        formData.files.add(MapEntry(
          'files',
          MultipartFile.fromBytes(file.bytes!, filename: file.name),
        ));
      } else if (file.path != null) {
        formData.files.add(MapEntry(
          'files',
          await MultipartFile.fromFile(file.path!, filename: file.name),
        ));
      }
    }
    if (templateId != null) {
      formData.fields.add(MapEntry('template_id', templateId));
    }

    final response = await _dio.post(
      '/upload/$projectId',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        receiveTimeout: const Duration(minutes: 10),
      ),
    );
    return UploadJob.fromJson(response.data as Map<String, dynamic>);
  }

  /// Poll the job status once.
  Future<UploadJob> getJobStatus(String projectId, String jobId) async {
    final response = await _dio.get('/upload/$projectId/status/$jobId');
    return UploadJob.fromJson(response.data as Map<String, dynamic>);
  }

  /// Poll every [interval] until status == done or failed.
  /// Calls [onProgress] with each intermediate [UploadJob].
  /// Returns the final [UploadJob].
  Future<UploadJob> pollUntilDone(
    String projectId,
    String jobId, {
    Duration interval = const Duration(seconds: 2),
    void Function(UploadJob)? onProgress,
  }) async {
    final completer = Completer<UploadJob>();
    Timer.periodic(interval, (timer) async {
      try {
        final job = await getJobStatus(projectId, jobId);
        onProgress?.call(job);
        if (job.status == 'done' || job.status == 'failed') {
          timer.cancel();
          completer.complete(job);
        }
      } catch (e) {
        timer.cancel();
        completer.completeError(e);
      }
    });
    return completer.future;
  }
}
