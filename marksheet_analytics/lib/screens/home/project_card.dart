import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../models/project.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/status_badge.dart';

class ProjectCard extends StatefulWidget {
  final Project project;
  final VoidCallback onTap;
  final Future<bool> Function() onDelete;
  final int index;

  const ProjectCard({
    super.key,
    required this.project,
    required this.onTap,
    required this.onDelete,
    required this.index,
  });

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _animController, curve: Curves.easeIn));

    Future.delayed(Duration(milliseconds: widget.index * 100), () {
      if (mounted) _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Dismissible(
          key: ValueKey(widget.project.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: AppColors.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            final confirm = await ConfirmDialog.show(context, title: 'Delete Project', content: 'Are you sure you want to delete ${widget.project.name}?');
            if (confirm) {
               return await widget.onDelete();
            }
            return false;
          },
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.project.name, style: AppTextStyles.h2.copyWith(fontSize: 18)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(widget.project.typeLabel, style: AppTextStyles.caption),
                              const SizedBox(width: 8),
                              StatusBadge(status: widget.project.status),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                      onSelected: (val) async {
                        if (val == 'delete') {
                           final confirm = await ConfirmDialog.show(context, title: 'Delete Project', content: 'Are you sure you want to delete ${widget.project.name}?');
                           if (confirm) {
                              widget.onDelete();
                           }
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.error))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
