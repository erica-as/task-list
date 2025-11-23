import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import '../models/category.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import '../services/sensor_service.dart';
import '../services/location_service.dart';
import '../services/camera_service.dart';
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
  Position? _nearbyPosition;

  // Estado da tela
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupShakeDetection();
  }

  @override
  void dispose() {
    SensorService.instance.stop();
    super.dispose();
  }

  void _setupShakeDetection() {
    SensorService.instance.startShakeDetection(() {
      _showShakeDialog();
    });
  }

  void _showShakeDialog() {
    final pendingTasks = _filteredTasks.where((t) => !t.completed).toList();

    if (pendingTasks.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Nenhuma tarefa pendente!'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.vibration, color: Colors.deepPurple),
            SizedBox(width: 8),
            Expanded(child: Text('Shake detectado!')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Selecione uma tarefa para completar:'),
            const SizedBox(height: 16),
            ...pendingTasks
                .take(3)
                .map(
                  (task) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => _completeTaskByShake(task),
                    ),
                  ),
                ),
            if (pendingTasks.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+ ${pendingTasks.length - 3} outras',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeTaskByShake(Task task) async {
    try {
      final updated = task.copyWith(
        completed: true,
        completedAt: DateTime.now(),
        completedBy: 'shake',
      );

      await DatabaseService.instance.update(updated);
      if (mounted) Navigator.pop(context);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "${task.title}" completa via shake!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
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

  // Lógica de filtro 'nearby' (da atividade)
  Future<void> _filterByNearby() async {
    final position = await LocationService.instance.getCurrentLocation();

    if (position == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Não foi possível obter localização'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _nearbyPosition = position;
      _filter = 'nearby';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 Mostrando tarefas próximas (raio de 1km)'),
          backgroundColor: Colors.deepPurple,
        ),
      );
    }
  }

  List<Task> get _filteredTasks {
    var tasks = _tasks;

    // 1. Filtro por Categoria
    if (_categoryFilter != 'all') {
      tasks = tasks.where((t) => t.categoryId == _categoryFilter).toList();
    }

    // 2. Filtro por Status
    switch (_filter) {
      case 'completed':
        tasks = tasks.where((t) => t.completed).toList();
        break;
      case 'pending':
        tasks = tasks.where((t) => !t.completed).toList();
        break;
      case 'nearby': // NOVO
        if (_nearbyPosition != null) {
          tasks = tasks.where((task) {
            if (!task.hasLocation) return false;
            final distance = LocationService.instance.calculateDistance(
              _nearbyPosition!.latitude,
              _nearbyPosition!.longitude,
              task.latitude!,
              task.longitude!,
            );
            return distance <= 1000;
          }).toList();
        }
        break;
      default:
    }

    return tasks;
  }

  // ATUALIZADO: _toggleTask agora usa a lógica de 'manual'
  Future<void> _toggleTask(Task task) async {
    try {
      final updated = task.copyWith(
        completed: !task.completed,
        completedAt: !task.completed ? DateTime.now() : null,
        completedBy: !task.completed ? 'manual' : null,
      );

      await DatabaseService.instance.update(updated);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
      try {
        if (task.hasPhoto && task.photoPath != null) {
          await CameraService.instance.deletePhoto(task.photoPath!);
        }

        await DatabaseService.instance.delete(task.id!);
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Tarefa deletada'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
          );
        }
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

  // Estatísticas
  Map<String, int> _calculateStats(List<Task> tasks) {
    final total = tasks.length;
    final completed = tasks.where((t) => t.completed).length;
    final pending = total - completed;
    final completionRate = total > 0 ? ((completed / total) * 100).round() : 0;

    return {
      'total': total,
      'completed': completed,
      'pending': pending,
      'completionRate': completionRate,
    };
  }

  @override
  Widget build(BuildContext context) {
    // ATENÇÃO: A atividade usa _filteredTasks para estatísticas!
    final filteredTasks = _filteredTasks;
    // O card de stats deve ser sobre TODAS as tarefas, não só as filtradas.
    // Vou usar _tasks para o 'stats', mas _filteredTasks para a lista.
    final stats = _calculateStats(
      _tasks,
    ); // FIX: Usando _tasks, não _filteredTasks

    // Cor da AppBar da Atividade (Azul)
    final appBarColor = Colors.deepPurple;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Tarefas'),
        backgroundColor: appBarColor, // ATUALIZADO: Cor da atividade
        foregroundColor: Colors.white,
        actions: [
          // MANTIDO: Seu filtro de Categoria
          PopupMenuButton<String>(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Filtrar por Categoria',
            onSelected: (value) => setState(() {
              _categoryFilter = value;
            }),
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

          // ATUALIZADO: Filtro de Status com 'nearby'
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtrar por Status',
            onSelected: (value) {
              // Lógica de filtro da atividade
              if (value == 'nearby') {
                _filterByNearby();
              } else {
                setState(() {
                  _filter = value;
                  _nearbyPosition = null; // Limpa o filtro nearby
                  // Não recarrega os dados, o getter faz o trabalho
                });
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(Icons.list_alt), // Ícone da atividade
                    SizedBox(width: 8),
                    Text('Todas'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pending',
                child: Row(
                  children: [
                    Icon(Icons.pending_outlined), // Ícone da atividade
                    SizedBox(width: 8),
                    Text('Pendentes'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'completed',
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline), // Ícone da atividade
                    SizedBox(width: 8),
                    Text('Concluídas'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'nearby', // NOVO
                child: Row(
                  children: [
                    Icon(Icons.near_me),
                    SizedBox(width: 8),
                    Text('Próximas'),
                  ],
                ),
              ),
            ],
          ),

          // NOVO: Botão de Info da atividade
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('💡 Dicas'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('• Toque no card para editar'),
                      SizedBox(height: 8),
                      Text('• Marque como completa com checkbox'),
                      SizedBox(height: 8),
                      Text('• Sacuda o celular para completar rápido!'),
                      SizedBox(height: 8),
                      Text('• Use filtros para organizar'),
                      SizedBox(height: 8),
                      Text('• Adicione fotos e localização'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Entendi'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      // ATUALIZADO: Corpo (Body) da atividade
      body: RefreshIndicator(
        onRefresh: _loadData, // MANTIDO: _loadData
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // ATUALIZADO: CARD DE ESTATÍSTICAS
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.deepPurple.shade400,
                          Colors.deepPurple.shade700,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // ATUALIZADO: Usando _StatItem
                        _StatItem(
                          label: 'Total',
                          value: stats['total'].toString(),
                          icon: Icons.list_alt,
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        _StatItem(
                          label: 'Concluídas',
                          value: stats['completed'].toString(),
                          icon: Icons.check_circle,
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        _StatItem(
                          label: 'Taxa',
                          value: '${stats['completionRate']}%',
                          icon: Icons.trending_up,
                        ),
                      ],
                    ),
                  ),

                  // LISTA DE TAREFAS
                  Expanded(
                    child: filteredTasks.isEmpty
                        ? _buildEmptyState() // ATUALIZADO: Novo Empty State
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredTasks.length,
                            itemBuilder: (context, index) {
                              final task = filteredTasks[index];
                              // MANTIDO: Seu TaskCard com onToggle e onShare
                              // A atividade mudou o onToggle para onCheckboxChanged
                              // Se o seu TaskCard quebrar, você terá que
                              // mudar o nome do parâmetro aqui.
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
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTaskForm(), // MANTIDO: Sua chamada
        backgroundColor: appBarColor, // ATUALIZADO: Cor da atividade
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nova Tarefa'),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (_filter) {
      case 'pending':
        message = 'Nenhuma tarefa pendente!';
        icon = Icons.check_circle_outline;
        break;
      case 'completed':
        message = 'Nenhuma tarefa concluída ainda';
        icon = Icons.pending_outlined;
        break;
      case 'nearby':
        message = 'Nenhuma tarefa próxima';
        icon = Icons.near_me;
        break;
      default:
        if (_categoryFilter != 'all') {
          message = 'Nenhuma tarefa nesta categoria';
          icon = Icons.folder_off_outlined;
        } else {
          message = 'Nenhuma tarefa ainda.\nToque em + para criar!';
          icon = Icons.add_task;
        }
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
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
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
        ),
      ],
    );
  }
}
