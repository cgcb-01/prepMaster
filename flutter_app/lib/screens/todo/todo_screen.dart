import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../api/api_client.dart';
import '../../models/misc_models.dart';
import '../../widgets/async_section.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});
  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final _sectionKey = GlobalKey<AsyncSectionState<List<TodoItem>>>();

  Future<List<TodoItem>> _fetch() async {
    final resp = await ApiClient.dio.get('/api/todo/');
    final list = (resp.data is Map ? resp.data['results'] : resp.data) as List;
    return list.map((j) => TodoItem.fromJson(j)).toList();
  }

  Future<void> _addTodo() async {
    final controller = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 1));
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New To-Do'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: controller, decoration: const InputDecoration(labelText: 'Task title')),
              const SizedBox(height: 12),
              Row(children: [
                Text('Due: ${dueDate.toString().split(' ').first}'),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(context: ctx, initialDate: dueDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (picked != null) setDialogState(() => dueDate = picked);
                  },
                  child: const Text('Change'),
                ),
              ]),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().isEmpty) return;
                await ApiClient.dio.post('/api/todo/', data: TodoItem(id: 0, title: controller.text.trim(), description: '', dueDate: dueDate, isCompleted: false).toCreateJson());
                if (ctx.mounted) Navigator.pop(ctx);
                _sectionKey.currentState?.refresh();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _complete(TodoItem todo) async {
    await ApiClient.dio.post('/api/todo/${todo.id}/complete/');
    _sectionKey.currentState?.refresh();
  }

  Future<void> _delete(TodoItem todo) async {
    await ApiClient.dio.delete('/api/todo/${todo.id}/delete/');
    _sectionKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('To-Do', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                Text('Missed items lower your rating, completed ones raise it', style: TextStyle(color: secondaryText, fontSize: 12.5)),
              ]),
              ElevatedButton.icon(onPressed: _addTodo, icon: const Icon(Icons.add), label: const Text('New Task')),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AsyncSection<List<TodoItem>>(
              key: _sectionKey,
              fetcher: _fetch,
              builder: (context, todos, refresh) {
                final completedCount = todos.where((t) => t.isCompleted).length;
                final completionPercent = todos.isEmpty ? 0.0 : completedCount / todos.length * 100;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: completionPercent / 100, minHeight: 8, backgroundColor: borderColor, valueColor: const AlwaysStoppedAnimation(AppColors.purple)))),
                        const SizedBox(width: 12),
                        Text('${completionPercent.toStringAsFixed(0)}% completed', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: todos.isEmpty
                          ? Center(child: Text('No tasks yet — add one to get started.', style: TextStyle(color: secondaryText)))
                          : ListView.separated(
                              itemCount: todos.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final t = todos[i];
                                final overdue = !t.isCompleted && t.dueDate.isBefore(DateTime.now());
                                return Container(
                                  decoration: BoxDecoration(border: Border.all(color: overdue ? Colors.redAccent.withOpacity(0.5) : borderColor), borderRadius: BorderRadius.circular(10)),
                                  child: ListTile(
                                    leading: Checkbox(value: t.isCompleted, activeColor: AppColors.purple, onChanged: t.isCompleted ? null : (_) => _complete(t)),
                                    title: Text(t.title, style: TextStyle(fontSize: 13.5, decoration: t.isCompleted ? TextDecoration.lineThrough : null, color: t.isCompleted ? secondaryText : null)),
                                    subtitle: Text('Due ${t.dueDate.toString().split(' ').first}${overdue ? ' · Overdue' : ''}', style: TextStyle(fontSize: 11, color: overdue ? Colors.redAccent : secondaryText)),
                                    trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => _delete(t)),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
