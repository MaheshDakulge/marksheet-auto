import '../core/api_client.dart';
import '../models/project.dart';
import '../models/student_result.dart';
import '../models/analytics_data.dart';

class ProjectService {
  static Future<List<Project>> getProjects() async {
    final response = await ApiClient.dio.get('/projects');
    return (response.data as List)
        .map((e) => Project.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Project> createProject(Map<String, dynamic> data) async {
    final response = await ApiClient.dio.post('/projects', data: data);
    return Project.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<void> deleteProject(String projectId) async {
    await ApiClient.dio.delete('/projects/$projectId');
  }

  static Future<List<StudentResult>> getStudentResults(String projectId) async {
    final response = await ApiClient.dio.get('/review/$projectId');
    return (response.data as List)
        .map((e) => StudentResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<AnalyticsData> getAnalytics(String projectId) async {
    final response = await ApiClient.dio.get('/analytics/$projectId');
    return AnalyticsData.fromJson(response.data as Map<String, dynamic>);
  }

  // FIX: was PATCH /review/result/{id} — backend uses PUT /review/{projectId}/result/{resultId}
  static Future<void> updateResult(
    String projectId,
    String resultId,
    Map<String, dynamic> data,
  ) async {
    await ApiClient.dio.put('/review/$projectId/result/$resultId', data: data);
  }

  // FIX: confirm multiple results at once
  static Future<Map<String, dynamic>> confirmResults(
    String projectId,
    List<String> resultIds,
  ) async {
    final response = await ApiClient.dio.post(
      '/review/$projectId/confirm',
      data: {'result_ids': resultIds, 'project_id': projectId},
    );
    return response.data as Map<String, dynamic>;
  }
}
