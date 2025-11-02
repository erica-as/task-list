import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/category.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import '../widgets/task_card.dart';
import 'task_form_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  // Estado das listas
  List<Task> _tasks = [];
  List<Category> _categories = [];

  // Estado dos filtros
  String _filter = 'all'; // 'all', 'completed', 'pending'
  String _categoryFilter = 'all';

  // Estado da tela
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Carrega tarefas e categorias
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final tasksFuture = DatabaseService.instance.readAll();
      final categoriesFuture = DatabaseService.instance.readAllCategories();

      final results = await Future.wait([tasksFuture, categoriesFuture]);

      if (mounted) {
        setState(() {
          _tasks = results[0] as List<Task>;
          _categories = results[1] as List<Category>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Task> get _filteredTasks {
    var tasks = _tasks;

    // 1. Filtro por Categoria
    if (_categoryFilter != 'all') {
      tasks = tasks.where((t) => t.categoryId == _categoryFilter).toList();
    }

    // 2. Filtro por Status (Existente)
    switch (_filter) {
      case 'completed':
        tasks = tasks.where((t) => t.completed).toList();
        break;
      case 'pending':
        tasks = tasks.where((t) => !t.completed).toList();
        break;
      default:
    }

    return tasks;
  }

  Future<void> _toggleTask(Task task) async {
    final updated = task.copyWith(completed: !task.completed);
    await DatabaseService.instance.update(updated);
    await _loadData();
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService.instance.delete(task.id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tarefa excluída'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _openTaskForm([Task? task]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TaskFormScreen(task: task)),
    );

    if (result == true) {
      await _loadData();
    }
  }

  String _getPriorityLabelForShare(String priority) {
    switch (priority) {
      case 'low':
        return 'Baixa';
      case 'medium':
        return 'Média';
      case 'high':
        return 'Alta';
      case 'urgent':
        return 'Urgente';
      default:
        return 'Média';
    }
  }

  // Método para formatar e compartilhar a tarefa
  Future<void> _shareTask(Task task) async {
    final String status = task.completed ? "✓ Concluída" : "□ Pendente";
    final String priority = _getPriorityLabelForShare(task.priority);
    final String category = task.category?.name ?? "Geral";

    final String textToShare =
        """
Tarefa: ${task.title}
Status: $status
Prioridade: $priority
Categoria: $category

${task.description.isNotEmpty ? 'Descrição: ${task.description}' : ''}
""";

    await Share.share(textToShare, subject: 'Tarefa: ${task.title}');
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _filteredTasks;
    final stats = _calculateStats(filteredTasks);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Tarefas'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Filtrar por Categoria',
            onSelected: (value) => setState(() => _categoryFilter = value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(
                      Icons.clear_all,
                      color: _categoryFilter == 'all'
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 8),
                    const Text('Todas as Categorias'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              ..._categories.map((category) {
                return PopupMenuItem(
                  value: category.id,
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 16,
                        color: _categoryFilter == category.id
                            ? category.color
                            : category.color.withOpacity(0.7),
                      ),
                      const SizedBox(width: 8),
                      Text(category.name),
                    ],
                  ),
                );
              }),
            ],
          ),

          // Filtro de Status (Existente)
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtrar por Status',
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(Icons.list),
                    SizedBox(width: 8),
                    Text('Todas'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pending',
                child: Row(
                  children: [
                    Icon(Icons.pending_actions),
                    SizedBox(width: 8),
                    Text('Pendentes'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'completed',
                child: Row(
                  children: [
                    Icon(Icons.check_circle),
                    SizedBox(width: 8),
                    Text('Concluídas'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_tasks.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.indigoAccent, Colors.purpleAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    Icons.list,
                    'Total',
                    stats['total'].toString(),
                  ),
                  _buildStatItem(
                    Icons.pending_actions,
                    'Pendentes',
                    stats['pending'].toString(),
                  ),
                  _buildStatItem(
                    Icons.check_circle,
                    'Concluídas',
                    stats['completed'].toString(),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredTasks.isEmpty
                ? _buildEmptyState(filteredTasks)
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: filteredTasks.length,
                      itemBuilder: (context, index) {
                        final task = filteredTasks[index];
                        return TaskCard(
                          task: task,
                          onTap: () => _openTaskForm(task),
                          onToggle: () => _toggleTask(task),
                          onDelete: () => _deleteTask(task),
                          onShare: () => _shareTask(task),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTaskForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nova Tarefa'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 32),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildEmptyState(List<Task> filteredTasks) {
    String message;
    IconData icon;

    if (_categoryFilter != 'all' && filteredTasks.isEmpty) {
      message = 'Nenhuma tarefa nesta categoria';
      icon = Icons.folder_off_outlined;
    } else {
      switch (_filter) {
        case 'completed':
          message = 'Nenhuma tarefa concluída ainda';
          icon = Icons.check_circle_outline;
          break;
        case 'pending':
          message = 'Nenhuma tarefa pendente';
          icon = Icons.pending_actions;
          break;
        default:
          message = 'Nenhuma tarefa cadastrada';
          icon = Icons.task_alt;
      }
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _openTaskForm(),
            icon: const Icon(Icons.add),
            label: const Text('Criar primeira tarefa'),
          ),
        ],
      ),
    );
  }

  Map<String, int> _calculateStats(List<Task> tasks) {
    return {
      'total': tasks.length,
      'completed': tasks.where((t) => t.completed).length,
      'pending': tasks.where((t) => !t.completed).length,
    };
  }
}
