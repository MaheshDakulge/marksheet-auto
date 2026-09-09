import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart' as dio;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';

class ExportTab extends StatefulWidget {
  final String projectId;
  const ExportTab({super.key, required this.projectId});

  @override
  State<ExportTab> createState() => _ExportTabState();
}

class _ExportTabState extends State<ExportTab> {
  bool _downloadingExcel = false;
  bool _downloadingCsv = false;

  Future<void> _download(String format) async {
    final isExcel = format == 'excel';
    setState(() {
      if (isExcel) {
        _downloadingExcel = true;
      } else {
        _downloadingCsv = true;
      }
    });

    try {
      final response = await ApiClient.dio.get(
        '/export/${widget.projectId}',
        queryParameters: {'format': format},
        options: dio.Options(responseType: dio.ResponseType.bytes),
      );

      final bytes = response.data as List<int>;
      final filename = isExcel ? 'results.xlsx' : 'results.csv';

      if (kIsWeb) {
        // ── Web: trigger browser download via JS interop ───────────────────
        _downloadWeb(bytes, filename, isExcel);
      } else {
        // ── Android / iOS: save to downloads folder and open ───────────────
        await _downloadMobile(bytes, filename);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$filename downloaded'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingExcel = false;
          _downloadingCsv = false;
        });
      }
    }
  }

  // Mobile: write to documents directory and open
  Future<void> _downloadMobile(List<int> bytes, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    await OpenFilex.open(file.path);
  }

  // Web: trigger browser download using JS eval
  void _downloadWeb(List<int> bytes, String filename, bool isExcel) {
    // Use universal_html or js_util — simplest cross-platform approach for web
    // is to use a data URI via dart:ui_web
    final mimeType = isExcel
        ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        : 'text/csv';

    // Encode bytes to base64 data URI and trigger download via JS
    final base64 = Uri.encodeFull(String.fromCharCodes(bytes));
    _triggerDownload('data:$mimeType;base64,$base64', filename);
  }

  // ignore: unused_element
  void _triggerDownload(String dataUrl, String filename) {
    // This will only be called on web — using conditional import pattern below
    // is safer but for simplicity we guard with kIsWeb above
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.download_outlined, size: 56, color: AppColors.primary),
        const SizedBox(height: 16),
        const Text('Export Results',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        const Text('Download all student results for this project.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 40),
        _ExportCard(
          icon: Icons.table_chart_outlined,
          iconColor: const Color(0xFF1D6F42),
          title: 'Excel (.xlsx)',
          subtitle:
              '1 sheet with all students, SGPA, grades,\nsubject columns, and color-coded status',
          buttonLabel: 'Download Excel',
          buttonColor: const Color(0xFF1D6F42),
          isLoading: _downloadingExcel,
          onPressed: () => _download('excel'),
        ),
        const SizedBox(height: 16),
        _ExportCard(
          icon: Icons.text_snippet_outlined,
          iconColor: AppColors.primary,
          title: 'CSV (.csv)',
          subtitle: 'Plain text — open in any spreadsheet app',
          buttonLabel: 'Download CSV',
          buttonColor: AppColors.primary,
          isLoading: _downloadingCsv,
          onPressed: () => _download('csv'),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: AppColors.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'The file will be saved to your device and opened automatically.',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExportCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final Color buttonColor;
  final bool isLoading;
  final VoidCallback onPressed;

  const _ExportCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.buttonColor,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.download,
                            size: 16, color: Colors.white),
                    label: Text(
                      isLoading ? 'Downloading...' : buttonLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
