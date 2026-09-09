import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants.dart';
import '../../services/upload_service.dart';
import '../../widgets/animated_progress_bar.dart';

class UploadTab extends StatefulWidget {
  final String projectId;
  const UploadTab({super.key, required this.projectId});

  @override
  State<UploadTab> createState() => _UploadTabState();
}

class _UploadTabState extends State<UploadTab> {
  bool _isUploading = false;
  double _progress = 0.0;
  String _statusMessage = 'Select PDF files to upload';

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return;

    final paths = result.files.map((e) => e.path!).toList();

    setState(() {
      _isUploading = true;
      _progress = 0.1;
      _statusMessage = 'Uploading ${paths.length} files...';
    });

    try {
      final job = await UploadService.uploadPdfs(widget.projectId, paths, (count, total) {
        setState(() => _progress = 0.1 + (0.4 * (count / total)));
      });
      _pollStatus(job.id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _statusMessage = 'Upload failed: $e';
        });
      }
    }
  }

  Future<void> _pollStatus(String jobId) async {
    bool done = false;
    while (!done && mounted) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final job = await UploadService.checkJobStatus(widget.projectId, jobId);
        if (job.status == 'done' || job.status == 'failed') {
          done = true;
          setState(() {
            _progress = 1.0;
            _statusMessage = job.status == 'done' 
              ? 'Successfully processed ${job.processed} files!' 
              : 'Job failed: ${job.errorMessage}';
            _isUploading = false;
          });
        } else {
          setState(() {
            final p = job.fileCount > 0 ? (job.processed / job.fileCount) : 0.0;
            _progress = 0.5 + (0.4 * p);
            _statusMessage = 'Processing records... (${job.processed}/${job.fileCount})';
          });
        }
      } catch (e) {
        done = true;
        setState(() {
          _isUploading = false;
          _statusMessage = 'Polling failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_upload_outlined, size: 80, color: AppColors.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 24),
          Text(_statusMessage, style: AppTextStyles.body, textAlign: TextAlign.center),
          const SizedBox(height: 32),
          if (_isUploading || _progress > 0) AnimatedProgressBar(progress: _progress),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _isUploading ? null : _pickAndUpload,
            icon: const Icon(Icons.attach_file),
            label: const Text('Select Marksheets'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          )
        ],
      ),
    );
  }
}
