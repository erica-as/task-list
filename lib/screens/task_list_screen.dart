import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/database_service.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({Key? key}) : super(key: key);

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> _tasks = [];
  final _titleController = TextEditingController();
  String _selectedPriority = 'medium';
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final tasks = await DatabaseService.instance.readAll();
    print('Tasks carregadas: ${tasks.length}');
    setState(() {
      if (_filter == 'completed') {
        _tasks = tasks.where((t) => t.completed).toList();
      } else if (_filter == 'pending') {
        _tasks = tasks.where((t) => !t.completed).toList();
      } else {
        _tasks = tasks;
      }
    });
  }

  Future<void> _addTask() async {
    if (_titleController.text.trim().isEmpty) return;

    final task = Task(
      title: _titleController.text.trim(),
      priority: _selectedPriority,
    );
    await DatabaseService.instance.create(task);
    print('Tarefa adicionada: ${task.toMap()}');
    _titleController.clear();
    _loadTasks();
  }

  Future<void> _toggleTask(Task task) async {
    final updated = task.copyWith(completed: !task.completed);
    await DatabaseService.instance.update(updated);
    _loadTasks();
  }

  Future<void> _editTask(Task task) async {
    final titleController = TextEditingController(text: task.title);
    String selectedPriority = task.priority;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Tarefa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedPriority,
              decoration: const InputDecoration(labelText: 'Prioridade'),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Baixa')),
                DropdownMenuItem(value: 'medium', child: Text('Média')),
                DropdownMenuItem(value: 'high', child: Text('Alta')),
              ],
              onChanged: (value) {
                if (value != null) selectedPriority = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (result == true) {
      final updatedTask = task.copyWith(
        title: titleController.text.trim(),
        priority: selectedPriority,
      );
      await DatabaseService.instance.update(updatedTask);
      _loadTasks();
    }
  }

  Future<void> _deleteTask(String id) async {
    await DatabaseService.instance.delete(id);
    _loadTasks();
  }

  int get _totalTasks => _tasks.length;
  int get _completedTasks => _tasks.where((t) => t.completed).length;
  int get _pendingTasks => _tasks.where((t) => !t.completed).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Tarefas'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _filter = value);
              _loadTasks();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('Todas')),
              const PopupMenuItem(value: 'completed', child: Text('Completas')),
              const PopupMenuItem(value: 'pending', child: Text('Pendentes')),
            ],
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCounter('Total', _totalTasks, Colors.blue),
                _buildCounter('Concluídas', _completedTasks, Colors.green),
                _buildCounter('Pendentes', _pendingTasks, Colors.orange),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'Nova tarefa...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedPriority,
                    decoration: const InputDecoration(
                      labelText: 'Prioridade',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Baixa')),
                      DropdownMenuItem(value: 'medium', child: Text('Média')),
                      DropdownMenuItem(value: 'high', child: Text('Alta')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedPriority = value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addTask,
                  child: const Text('Adicionar'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _tasks.isEmpty
                ? const Center(child: Text('Nenhuma tarefa encontrada.'))
                : ListView.builder(
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: Checkbox(
                            value: task.completed,
                            onChanged: (_) => _toggleTask(task),
                          ),
                          title: Text(
                            task.title,
                            style: TextStyle(
                              decoration: task.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            'Prioridade: ${_translatePriority(task.priority)}',
                            style: TextStyle(
                              color: _getPriorityColor(task.priority),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editTask(task),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteTask(task.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounter(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label),
      ],
    );
  }

  String _translatePriority(String priority) {
    switch (priority) {
      case 'low':
        return 'Baixa';
      case 'medium':
        return 'Média';
      case 'high':
        return 'Alta';
      default:
        return priority;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
