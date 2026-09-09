import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/student_result.dart';
import '../../services/project_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';

class ReviewTab extends StatefulWidget {
  final String projectId;
  final Function(int) onNavigate;

  const ReviewTab({
    super.key,
    required this.projectId,
    required this.onNavigate,
  });

  @override
  State<ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<ReviewTab> {
  List<StudentResult> _results = [];
  bool _isLoading = true;
  bool _isConfirming = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() => _isLoading = true);
    try {
      final res = await ProjectService.getStudentResults(widget.projectId);
      if (mounted) setState(() => _results = res);
    } catch (e) {
      if (mounted) _snack('Failed to load: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmAll() async {
    if (_results.isEmpty) return;
    setState(() => _isConfirming = true);
    try {
      final ids = _results.map((e) => e.id).toList();
      final response =
          await ProjectService.confirmResults(widget.projectId, ids);
      if (mounted) {
        _snack('All results confirmed!');
        if (response['project_fully_reviewed'] == true) {
          widget.onNavigate(2);
        } else {
          _loadResults();
        }
      }
    } catch (e) {
      if (mounted) _snack('Failed to confirm: $e', error: true);
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
    ));
  }

  List<StudentResult> get _filtered {
    if (_search.isEmpty) return _results;
    final q = _search.toLowerCase();
    return _results
        .where(
          (r) =>
              (r.studentName ?? '').toLowerCase().contains(q) ||
              r.studentPrn.toLowerCase().contains(q) ||
              (r.seatNo ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  void _openDetail(StudentResult r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(
        result: r,
        projectId: widget.projectId,
        onEdit: () {
          Navigator.pop(context);
          _openEdit(r);
        },
      ),
    );
  }

  void _openEdit(StudentResult r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditResultSheet(
        projectId: widget.projectId,
        result: r,
        onSaved: () {
          Navigator.pop(context);
          _loadResults();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final allConfirmed =
        _results.isNotEmpty && _results.every((r) => r.isConfirmed);

    return Column(
      children: [
        // ── Action bar ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Search name, PRN or seat...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: AppColors.background,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed:
                        (_results.isEmpty || _isConfirming || allConfirmed)
                            ? null
                            : _confirmAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                    icon: _isConfirming
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Icon(
                            allConfirmed
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
                            size: 16),
                    label: Text(allConfirmed ? 'Confirmed' : 'Confirm All',
                        style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('${_filtered.length} of ${_results.length} students',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  const Spacer(),
                  Text(
                    '${_results.where((r) => r.isConfirmed).length} confirmed',
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.success),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── List ──────────────────────────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadResults,
            child: _filtered.isEmpty
                ? EmptyState(
                    title: 'No Results Found',
                    message: 'Upload marksheets to see extracted data here.',
                    icon: Icons.checklist,
                    buttonText: 'Refresh',
                    onActionButtonPressed: _loadResults,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) {
                      final r = _filtered[i];
                      return _buildCard(r);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(StudentResult r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: r.isFlagged
              ? AppColors.error.withValues(alpha: 0.5)
              : r.isConfirmed
                  ? AppColors.success.withValues(alpha: 0.3)
                  : Colors.grey.shade200,
          width: r.isFlagged ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: () => _openDetail(r),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Name + status + edit
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.studentName ?? 'Unknown Name',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                  ),
                  if (r.isConfirmed)
                    const Icon(Icons.check_circle,
                        color: AppColors.success, size: 18)
                  else if (r.isFlagged)
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 18),
                  const SizedBox(width: 6),
                  StatusBadge(status: r.status),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _openEdit(r),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.edit_outlined,
                          size: 16, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Row 2: PRN | Seat | Semester
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _tag(Icons.badge_outlined, 'PRN: ${r.studentPrn}'),
                  _tag(Icons.chair_outlined, 'Seat: ${r.seatNo ?? "—"}'),
                  if (r.rank != null)
                    _tag(Icons.leaderboard_outlined, 'Rank: ${r.rank}'),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _tag(Icons.school_outlined, r.examination ?? '—'),
                  _tag(Icons.calendar_today_outlined, r.semester ?? '—'),
                ],
              ),
              const SizedBox(height: 10),

              // Row 3: SGPA | CGPA | Credits | EGP stats
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat('SGPA', r.sgpa?.toStringAsFixed(2) ?? '—',
                        AppColors.primary),
                    _vDivider(),
                    _stat('CGPA', r.cgpa?.toStringAsFixed(2) ?? '—',
                        AppColors.secondary),
                    _vDivider(),
                    _stat('Credits', r.totalCredits?.toStringAsFixed(0) ?? '—',
                        AppColors.success),
                    _vDivider(),
                    _stat('EGP', r.totalEgp?.toStringAsFixed(1) ?? '—',
                        const Color(0xFF7C3AED)),
                  ],
                ),
              ),

              // Subject count hint
              if (r.subjectMarks.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.menu_book_outlined,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                        '${r.subjectMarks.length} subjects  •  tap card to view all',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ],

              // Error banner
              if (r.errors.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 14, color: AppColors.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(r.errors.join(', '),
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 3),
          Flexible(
            child: Text(text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
        ],
      );

  Widget _stat(String label, String value, Color color) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
        ],
      );

  Widget _vDivider() => Container(
      width: 1,
      height: 28,
      color: AppColors.textSecondary.withValues(alpha: 0.15));
}

// ── Full Detail Sheet ─────────────────────────────────────────────────────────
class _DetailSheet extends StatelessWidget {
  final StudentResult result;
  final String projectId;
  final VoidCallback onEdit;

  const _DetailSheet(
      {required this.result, required this.projectId, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final r = result;
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.studentName ?? 'Unknown',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('PRN: ${r.studentPrn}  •  Seat: ${r.seatNo ?? "—"}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                      Text('${r.examination ?? ""}  •  ${r.semester ?? ""}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusBadge(status: r.status),
                    if (r.rank != null) ...[
                      const SizedBox(height: 4),
                      Text('Rank #${r.rank}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Stats bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _hStat('SGPA', r.sgpa?.toStringAsFixed(2) ?? '—'),
                _hStat('CGPA', r.cgpa?.toStringAsFixed(2) ?? '—'),
                _hStat('Credits', r.totalCredits?.toStringAsFixed(0) ?? '—'),
                _hStat('EGP', r.totalEgp?.toStringAsFixed(1) ?? '—'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Subject marks table header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(flex: 1, child: _TH('#')),
                Expanded(flex: 2, child: _TH('Code')),
                Expanded(flex: 5, child: _TH('Subject')),
                Expanded(flex: 1, child: _TH('Cr')),
                Expanded(flex: 2, child: _TH('Grade')),
                Expanded(flex: 2, child: _TH('GP')),
                Expanded(flex: 2, child: _TH('EGP')),
              ],
            ),
          ),
          const Divider(height: 1),

          // Subject rows
          Expanded(
            child: r.subjectMarks.isEmpty
                ? const Center(
                    child: Text('No subject marks found',
                        style: TextStyle(color: AppColors.textSecondary)))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: r.subjectMarks.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFF0F0F0)),
                    itemBuilder: (ctx, i) {
                      final m = r.subjectMarks[i];
                      final grade = m.gradeObtained ?? '—';
                      final gradeColor = _gradeColor(grade);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(flex: 1, child: _TD('${m.srNo ?? i + 1}')),
                            Expanded(
                                flex: 2,
                                child: _TD(m.courseCode ?? '—', bold: true)),
                            Expanded(flex: 5, child: _TD(m.courseName ?? '—')),
                            Expanded(
                                flex: 1,
                                child:
                                    _TD(m.credits?.toStringAsFixed(0) ?? '—')),
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: gradeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(grade,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: gradeColor)),
                              ),
                            ),
                            Expanded(
                                flex: 2,
                                child: _TD(
                                    m.gradePoint?.toStringAsFixed(1) ?? '—')),
                            Expanded(
                                flex: 2,
                                child: _TD(
                                    m.earnedGp?.toStringAsFixed(1) ?? '—',
                                    bold: true)),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Edit button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onEdit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                label: const Text('Edit Student',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hStat(String label, String value) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.white70)),
        ],
      );

  Color _gradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'O':
        return const Color(0xFF1A8C5B);
      case 'A+':
        return const Color(0xFF2563EB);
      case 'A':
        return const Color(0xFF3B82F6);
      case 'B+':
        return const Color(0xFF7C3AED);
      case 'B':
        return const Color(0xFFF59E0B);
      case 'C':
        return const Color(0xFFEA580C);
      case 'F':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: TextAlign.center,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary));
}

class _TD extends StatelessWidget {
  final String text;
  final bool bold;
  const _TD(this.text, {this.bold = false});
  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal));
}

// ── Edit Sheet ────────────────────────────────────────────────────────────────
class _EditResultSheet extends StatefulWidget {
  final String projectId;
  final StudentResult result;
  final VoidCallback onSaved;

  const _EditResultSheet(
      {required this.projectId, required this.result, required this.onSaved});

  @override
  State<_EditResultSheet> createState() => _EditResultSheetState();
}

class _EditResultSheetState extends State<_EditResultSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _seatNoCtrl;
  final Map<String, TextEditingController> _gradeCtrls = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.result.studentName);
    _seatNoCtrl = TextEditingController(text: widget.result.seatNo);
    for (var m in widget.result.subjectMarks) {
      _gradeCtrls[m.id] = TextEditingController(text: m.gradeObtained ?? '');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _seatNoCtrl.dispose();
    for (var c in _gradeCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final updatedMarks = widget.result.subjectMarks
          .map((m) => {
                'sr_no': m.srNo,
                'grade_obtained':
                    (_gradeCtrls[m.id]?.text.trim().toUpperCase()) ??
                        m.gradeObtained,
                'credits': m.credits,
                'grade_point': m.gradePoint,
                'earned_gp': m.earnedGp,
              })
          .toList();

      await ProjectService.updateResult(widget.projectId, widget.result.id, {
        'name': _nameCtrl.text.trim(),
        'seat_no': _seatNoCtrl.text.trim(),
        'subject_marks': updatedMarks,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Updated successfully'),
          backgroundColor: AppColors.success,
        ));
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('Edit Student',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  // ── Student info ───────────────────────────────────────────
                  _sectionLabel('Student Info'),
                  const SizedBox(height: 8),
                  _field(_nameCtrl, 'Student Name', Icons.person_outline),
                  const SizedBox(height: 10),
                  _field(_seatNoCtrl, 'Seat Number', Icons.chair_outlined),

                  // Read-only info
                  const SizedBox(height: 16),
                  _readOnly('PRN', widget.result.studentPrn),
                  const SizedBox(height: 8),
                  _readOnly('Examination', widget.result.examination ?? '—'),
                  const SizedBox(height: 8),
                  _readOnly('Semester', widget.result.semester ?? '—'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: _readOnly('SGPA',
                              widget.result.sgpa?.toStringAsFixed(2) ?? '—')),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _readOnly('CGPA',
                              widget.result.cgpa?.toStringAsFixed(2) ?? '—')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: _readOnly(
                              'Total Credits',
                              widget.result.totalCredits?.toStringAsFixed(0) ??
                                  '—')),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _readOnly(
                              'Total EGP',
                              widget.result.totalEgp?.toStringAsFixed(1) ??
                                  '—')),
                    ],
                  ),

                  // ── Subject grades ─────────────────────────────────────────
                  if (widget.result.subjectMarks.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionLabel('Subject Grades'),
                    const SizedBox(height: 4),
                    const Text('Edit grade letters (O, A+, A, B+, B, C, F)',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    ...widget.result.subjectMarks.map((m) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.courseCode ?? '—',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary)),
                                    Text(m.courseName ?? '—',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12)),
                                    Text(
                                        'Cr: ${m.credits?.toStringAsFixed(0) ?? "—"}  '
                                        'GP: ${m.gradePoint?.toStringAsFixed(1) ?? "—"}  '
                                        'EGP: ${m.earnedGp?.toStringAsFixed(1) ?? "—"}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 70,
                                child: TextFormField(
                                  controller: _gradeCtrls[m.id],
                                  textAlign: TextAlign.center,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  decoration: InputDecoration(
                                    labelText: 'Grade',
                                    labelStyle: const TextStyle(fontSize: 11),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 10),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return null;
                                    final valid = [
                                      'O',
                                      'A+',
                                      'A',
                                      'B+',
                                      'B',
                                      'C',
                                      'F'
                                    ];
                                    if (!valid.contains(v.trim().toUpperCase())) {
                                      return 'Invalid';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Save Changes',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: AppColors.textPrimary));

  Widget _field(TextEditingController ctrl, String label, IconData icon) =>
      TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      );

  Widget _readOnly(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Text('$label: ',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600))),
          ],
        ),
      );
}
