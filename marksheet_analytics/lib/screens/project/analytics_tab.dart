import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/analytics_data.dart';
import '../../services/project_service.dart';

class AnalyticsTab extends StatefulWidget {
  final String projectId;
  const AnalyticsTab({super.key, required this.projectId});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  AnalyticsData? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final d = await ProjectService.getAnalytics(widget.projectId);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 40),
        const SizedBox(height: 12),
        Text(_error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _load, child: const Text('Retry')),
      ]));
    }
    if (_data == null) return const Center(child: Text('No analytics data'));

    final d = _data!;
    final passPercent =
        d.totalStudents > 0 ? d.passCount / d.totalStudents * 100 : 0.0;
    final atktPercent =
        d.totalStudents > 0 ? d.atktCount / d.totalStudents * 100 : 0.0;
    final failPercent =
        d.totalStudents > 0 ? d.failCount / d.totalStudents * 100 : 0.0;
    final abovePercent =
        d.totalStudents > 0 ? d.aboveAvgCount / d.totalStudents * 100 : 0.0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          // ── Row 1: Total | Pass | ATKT | Fail ─────────────────────────────
          Row(children: [
            _StatCard(
                label: 'Total students',
                value: '${d.totalStudents}',
                sub: 'Full class',
                subColor: AppColors.textSecondary),
            const SizedBox(width: 10),
            _StatCard(
                label: 'Pass',
                value: '${d.passCount}',
                sub: '${passPercent.toStringAsFixed(1)}%',
                subColor: AppColors.success,
                valueColor: AppColors.success),
            const SizedBox(width: 10),
            _StatCard(
                label: 'ATKT',
                value: '${d.atktCount}',
                sub: '${atktPercent.toStringAsFixed(1)}%',
                subColor: AppColors.warning,
                valueColor: AppColors.warning),
            const SizedBox(width: 10),
            _StatCard(
                label: 'Fail',
                value: '${d.failCount}',
                sub: '${failPercent.toStringAsFixed(1)}%',
                subColor: AppColors.error,
                valueColor: AppColors.error),
          ]),
          const SizedBox(height: 10),

          // ── Row 2: Avg | Highest | Lowest | Above avg ─────────────────────
          Row(children: [
            _StatCard(
                label: 'Class avg SGPA', value: d.avgSgpa.toStringAsFixed(2)),
            const SizedBox(width: 10),
            _StatCard(
                label: 'Highest SGPA',
                value: d.topSgpa.toStringAsFixed(2),
                valueColor: AppColors.success),
            const SizedBox(width: 10),
            _StatCard(
                label: 'Lowest SGPA',
                value: d.minSgpa.toStringAsFixed(2),
                valueColor: AppColors.error),
            const SizedBox(width: 10),
            _StatCard(
                label: 'Above average',
                value: '${d.aboveAvgCount}',
                sub: '${abovePercent.toStringAsFixed(0)}%',
                subColor: AppColors.textSecondary),
          ]),
          const SizedBox(height: 20),

          // ── Result bar ─────────────────────────────────────────────────────
          _label('Result Overview'),
          const SizedBox(height: 10),
          _card(
              child: Column(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(children: [
                if (d.passCount > 0)
                  Expanded(
                      flex: d.passCount,
                      child: Container(height: 16, color: AppColors.success)),
                if (d.atktCount > 0)
                  Expanded(
                      flex: d.atktCount,
                      child: Container(height: 16, color: AppColors.warning)),
                if (d.failCount > 0)
                  Expanded(
                      flex: d.failCount,
                      child: Container(height: 16, color: AppColors.error)),
                if (d.passCount + d.atktCount + d.failCount == 0)
                  Expanded(
                      child:
                          Container(height: 16, color: Colors.grey.shade200)),
              ]),
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _legendItem(
                  AppColors.success, 'Pass', d.passCount, d.totalStudents),
              _legendItem(
                  AppColors.warning, 'ATKT', d.atktCount, d.totalStudents),
              _legendItem(
                  AppColors.error, 'Fail', d.failCount, d.totalStudents),
            ]),
          ])),
          const SizedBox(height: 20),

          // ── SGPA Distribution ──────────────────────────────────────────────
          if (d.sgpaHistogram.isNotEmpty) ...[
            _label('SGPA Distribution'),
            const SizedBox(height: 10),
            _card(child: _buildHistogram(d.sgpaHistogram)),
            const SizedBox(height: 20),
          ],

          // ── Topper board ───────────────────────────────────────────────────
          if (d.toppers.isNotEmpty) ...[
            _label('Topper Board'),
            const SizedBox(height: 10),
            _card(child: _buildToppers(d.toppers)),
            const SizedBox(height: 20),
          ],

          // ── Grade distribution ─────────────────────────────────────────────
          if (d.gradeDistribution.isNotEmpty) ...[
            _label('Grade Distribution'),
            const SizedBox(height: 10),
            _card(child: _buildGrades(d.gradeDistribution)),
            const SizedBox(height: 20),
          ],

          // ── Subject averages ───────────────────────────────────────────────
          if (d.subjectAverages.isNotEmpty) ...[
            _label('Subject-wise Average GP'),
            const SizedBox(height: 10),
            _card(child: _buildSubjects(d.subjectAverages)),
          ],
        ],
      ),
    );
  }

  // ── SGPA histogram ──────────────────────────────────────────────────────────
  Widget _buildHistogram(List<Map<String, dynamic>> histogram) {
    const colors = {
      '9-10': Color(0xFF00C896),
      '8-9': Color(0xFF4ADE80),
      '7-8': Color(0xFF86EFAC),
      '6-7': Color(0xFFF59E0B),
      '<6': Color(0xFFEF4444),
    };
    final maxCount = histogram.fold<int>(
        0, (m, e) => (e['count'] as int? ?? 0) > m ? (e['count'] as int) : m);

    return Column(
      children: histogram.map((item) {
        final range = item['range']?.toString() ?? '';
        final count = item['count'] as int? ?? 0;
        final ratio = maxCount > 0 ? count / maxCount : 0.0;
        final color = colors[range] ?? AppColors.primary;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            SizedBox(
                width: 38,
                child: Text(range,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary))),
            const SizedBox(width: 8),
            Expanded(
              child: Stack(children: [
                Container(
                    height: 14,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4))),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4))),
                ),
              ]),
            ),
            const SizedBox(width: 10),
            SizedBox(
                width: 24,
                child: Text('$count',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold))),
          ]),
        );
      }).toList(),
    );
  }

  // ── Topper board ────────────────────────────────────────────────────────────
  Widget _buildToppers(List<Map<String, dynamic>> toppers) {
    const medalColors = [
      Color(0xFFF59E0B),
      Color(0xFF94A3B8),
      Color(0xFFCD7F32)
    ];

    return Column(
      children: List.generate(toppers.length, (i) {
        final t = toppers[i];
        final rank = (t['rank'] as int?) ?? (i + 1);
        final sgpa = double.tryParse(t['sgpa']?.toString() ?? '0') ?? 0.0;
        final medalColor = i < 3 ? medalColors[i] : AppColors.textSecondary;

        return Column(
          children: [
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: medalColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle),
                  child: Center(
                      child: Text('$rank',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: medalColor))),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(t['name']?.toString() ?? 'Unknown',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      Text('PRN: ${t['prn'] ?? "—"}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                    ])),
                Text(sgpa.toStringAsFixed(2),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: i == 0
                            ? AppColors.success
                            : AppColors.textPrimary)),
              ]),
            ),
          ],
        );
      }),
    );
  }

  // ── Grade distribution ──────────────────────────────────────────────────────
  Widget _buildGrades(Map<String, dynamic> grades) {
    const gradeColors = {
      'O': Color(0xFF1A8C5B),
      'A+': Color(0xFF2563EB),
      'A': Color(0xFF3B82F6),
      'B+': Color(0xFF7C3AED),
      'B': Color(0xFFF59E0B),
      'C': Color(0xFFEA580C),
      'F': Color(0xFFEF4444),
    };
    final total = grades.values.fold<int>(0, (s, v) => s + (v as int? ?? 0));
    final sorted = grades.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    return Column(children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: sorted.map((e) {
          final color = gradeColors[e.key] ?? AppColors.textSecondary;
          final pct = total > 0 ? (e.value as int) / total * 100 : 0.0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(e.key,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: color, fontSize: 13)),
              const SizedBox(width: 6),
              Text('${e.value}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              Text('  (${pct.toStringAsFixed(0)}%)',
                  style: TextStyle(
                      fontSize: 11, color: color.withValues(alpha: 0.7))),
            ]),
          );
        }).toList(),
      ),
      const SizedBox(height: 14),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Row(
          children: sorted.where((e) => (e.value as int) > 0).map((e) {
            final color = gradeColors[e.key] ?? AppColors.textSecondary;
            return Expanded(
                flex: e.value as int,
                child: Container(height: 12, color: color));
          }).toList(),
        ),
      ),
    ]);
  }

  // ── Subject averages ────────────────────────────────────────────────────────
  Widget _buildSubjects(List<Map<String, dynamic>> subjects) {
    final maxGp = subjects.fold<double>(
        0,
        (m, e) => (double.tryParse(e['avg_gp']?.toString() ?? '0') ?? 0) > m
            ? double.parse(e['avg_gp'].toString())
            : m);

    return Column(
      children: subjects.map((s) {
        final avgGp = double.tryParse(s['avg_gp']?.toString() ?? '0') ?? 0.0;
        final ratio = maxGp > 0 ? avgGp / maxGp : 0.0;
        final color = avgGp >= 8
            ? AppColors.success
            : avgGp >= 6
                ? AppColors.warning
                : AppColors.error;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            SizedBox(
                width: 130,
                child: Text(s['subject']?.toString() ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary))),
            const SizedBox(width: 8),
            Expanded(
              child: Stack(children: [
                Container(
                    height: 12,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4))),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4))),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            SizedBox(
                width: 32,
                child: Text(avgGp.toStringAsFixed(1),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color))),
          ]),
        );
      }).toList(),
    );
  }

  // ── Small helpers ───────────────────────────────────────────────────────────
  Widget _label(String text) => Text(text.toUpperCase(),
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
          letterSpacing: 0.8));

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)
          ],
        ),
        child: child,
      );

  Widget _legendItem(Color color, String label, int count, int total) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0.0';
    return Row(children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text('$label  ',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      Text('$count',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      Text('  ($pct%)',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    ]);
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final String? sub;
  final Color? subColor, valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    this.sub,
    this.subColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03), blurRadius: 4)
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? AppColors.textPrimary)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub!,
                style: TextStyle(
                    fontSize: 10, color: subColor ?? AppColors.textSecondary)),
          ],
        ]),
      ),
    );
  }
}
