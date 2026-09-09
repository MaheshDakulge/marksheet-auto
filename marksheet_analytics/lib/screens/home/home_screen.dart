import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/project.dart';
import '../../services/project_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_overlay.dart';
import '../profile/profile_screen.dart';
import 'project_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Project> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    try {
      final p = await ProjectService.getProjects();
      if (mounted) setState(() => _projects = p);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load projects: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openCreateProject() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateProjectSheet(onCreated: () => Navigator.pop(context, true)),
    );
    if (result == true) _loadProjects();
  }

  Future<bool> _deleteProject(String id, int index) async {
    final deletedProject = _projects[index];
    // Optimistically remove from UI
    setState(() => _projects.removeAt(index));

    if (!mounted) return false;

    // Show Snackbar with Undo option
    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Project deleted'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            // Empty, handled by closed reason
          },
        ),
      ),
    );

    // Wait for the snackbar to close (either by timeout or UNDO action)
    final reason = await controller.closed;

    if (reason == SnackBarClosedReason.action) {
      // User pressed UNDO
      if (mounted) {
        setState(() => _projects.insert(index, deletedProject));
      }
      return false;
    } else {
      // User didn't press UNDO, safe to delete from backend
      try {
        await ProjectService.deleteProject(id);
        return true;
      } catch (e) {
        if (mounted) {
          // Revert UI on failure
          setState(() => _projects.insert(index, deletedProject));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e')),
          );
        }
        return false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects', style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.person_outline, color: AppColors.textPrimary),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      drawer: const ProfileDrawer(),
      body: LoadingOverlay(
        isLoading: _isLoading && _projects.isEmpty,
        child: RefreshIndicator(
          onRefresh: _loadProjects,
          child: _projects.isEmpty && !_isLoading
              ? ListView(
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                    EmptyState(
                      title: 'No Projects Yet',
                      message: 'Tap + to create your first project.',
                      icon: Icons.folder_open,
                      buttonText: 'Create Project',
                      onActionButtonPressed: _openCreateProject,
                    ),
                  ],
                )
              : ListView.builder(
                  itemCount: _projects.length,
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemBuilder: (context, index) {
                    final project = _projects[index];
                    return ProjectCard(
                      index: index,
                      project: project,
                      onTap: () => Navigator.of(context)
                          .pushNamed('/project', arguments: project.id)
                          .then((_) => _loadProjects()),
                      onDelete: () => _deleteProject(project.id, index),
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        // FIX: was empty () {} — now opens create project sheet
        onPressed: _openCreateProject,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── Inline create project bottom sheet ────────────────────────────────────────
class _CreateProjectSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateProjectSheet({required this.onCreated});

  @override
  State<_CreateProjectSheet> createState() => _CreateProjectSheetState();
}

class _CreateProjectSheetState extends State<_CreateProjectSheet> {
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _progCtrl = TextEditingController();
  final _examCtrl = TextEditingController();
  final _semCtrl  = TextEditingController();
  String _selectedType = 'semester';
  bool _loading   = false;

  @override
  void dispose() {
    _nameCtrl.dispose(); _progCtrl.dispose();
    _examCtrl.dispose(); _semCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ProjectService.createProject({
        'name':        _nameCtrl.text.trim(),
        'program':     _progCtrl.text.trim().isEmpty ? null : _progCtrl.text.trim(),
        'examination': _examCtrl.text.trim().isEmpty ? null : _examCtrl.text.trim(),
        'semester':    _semCtrl.text.trim().isEmpty  ? null : _semCtrl.text.trim(),
        'project_type': _selectedType,
      });
      widget.onCreated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('New Project', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _field(_nameCtrl, 'Project Name *', required: true),
            const SizedBox(height: 12),
            _field(_progCtrl, 'Program (e.g. M.Tech CSE)'),
            const SizedBox(height: 12),
            _field(_examCtrl, 'Examination'),
            const SizedBox(height: 12),
            _field(_semCtrl, 'Semester'),
            const SizedBox(height: 16),
            const Text('Project Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Single Semester', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    subtitle: const Text('One semester per marksheet page', style: TextStyle(fontSize: 14)),
                    leading: Radio<String>(
                      value: 'semester',
                      groupValue: _selectedType,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _selectedType = v!),
                    ),
                    onTap: () => setState(() => _selectedType = 'semester'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Full Year', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    subtitle: const Text('SEM I + SEM II combined on same page', style: TextStyle(fontSize: 14)),
                    leading: Radio<String>(
                      value: 'full_year',
                      groupValue: _selectedType,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _selectedType = v!),
                    ),
                    onTap: () => setState(() => _selectedType = 'full_year'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Create', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {bool required = false}) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
    );
  }
}