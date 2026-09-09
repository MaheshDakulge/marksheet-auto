import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/teacher.dart';
import '../../services/auth_service.dart';
import '../../widgets/loading_overlay.dart';

class ProfileDrawer extends StatefulWidget {
  const ProfileDrawer({super.key});
  @override
  State<ProfileDrawer> createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends State<ProfileDrawer> {
  Teacher? _teacher;
  bool _isLoading = false;

  final _nameCtrl = TextEditingController();
  final _collegeCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTeacher();
  }

  Future<void> _loadTeacher() async {
    final t = await AuthService.getCurrentTeacher();
    if (mounted) {
      setState(() {
        _teacher = t;
        if (t != null) {
          _nameCtrl.text = t.name;
          _collegeCtrl.text = t.college ?? '';
          _deptCtrl.text = t.department ?? '';
        }
      });
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final updated = await AuthService.updateProfile(
        _nameCtrl.text.trim(),
        _collegeCtrl.text.trim().isEmpty ? null : _collegeCtrl.text.trim(),
        _deptCtrl.text.trim().isEmpty ? null : _deptCtrl.text.trim(),
      );
      setState(() => _teacher = updated);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_teacher == null) return const Drawer(child: Center(child: CircularProgressIndicator()));

    return Drawer(
      child: LoadingOverlay(
        isLoading: _isLoading,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                color: AppColors.primary,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Text(_getInitials(_teacher!.name), style: const TextStyle(fontSize: 28, color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                    Text(_teacher!.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(_teacher!.email, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text('Edit Profile', style: AppTextStyles.h2),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _collegeCtrl,
                      decoration: const InputDecoration(labelText: 'College (Optional)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _deptCtrl,
                      decoration: const InputDecoration(labelText: 'Department (Optional)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _updateProfile,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(double.infinity, 48)),
                      child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text('Logout', style: TextStyle(color: AppColors.error)),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
