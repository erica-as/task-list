import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'database_service.dart';
import '../models/task.dart';

class SyncService {
  static final SyncService instance = SyncService._init();
  SyncService._init();

  final _connectivity = Connectivity();
  StreamSubscription? _subscription;

  // URL da sua API (Mock ou Real)
  final String _baseUrl = 'https://sua-api.com/tasks';

  // Notificador para a UI saber se está online
  final ValueNotifier<bool> isOnline = ValueNotifier(false);

  void initialize() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      // results é uma lista no connectivity_plus v6+
      final result = results.first;
      bool online = result != ConnectivityResult.none;
      isOnline.value = online;

      if (online) {
        print('🌐 Conexão restaurada! Iniciando sincronização...');
        _processSyncQueue();
        _pullFromApi(); // Baixar mudanças do servidor
      } else {
        print('📴 Modo Offline ativado');
      }
    });
  }

  // 1. Processar a fila (Upload de mudanças locais)
  Future<void> _processSyncQueue() async {
    final queue = await DatabaseService.instance.getSyncQueue();

    for (var item in queue) {
      bool success = false;
      final action = item['action'];
      final payload = jsonDecode(item['payload']);
      final queueId = item['id'];

      try {
        switch (action) {
          case 'CREATE':
            // success = await _apiCreate(payload);
            // Simulação:
            await Future.delayed(const Duration(milliseconds: 500));
            success = true;
            break;
          case 'UPDATE':
            // success = await _apiUpdate(payload);
            await Future.delayed(const Duration(milliseconds: 500));
            success = true;
            break;
          case 'DELETE':
            // success = await _apiDelete(payload['id']);
            success = true;
            break;
        }

        if (success) {
          await DatabaseService.instance.removeFromQueue(queueId);
          // Marca a tarefa como sincronizada localmente
          if (item['taskId'] != null && action != 'DELETE') {
            // Atualizar flag isSynced = 1 no banco
            // await DatabaseService.instance.markAsSynced(item['taskId']);
          }
          print('✅ Item da fila $queueId processado ($action)');
        }
      } catch (e) {
        print('❌ Erro ao processar fila: $e');
      }
    }
  }

  // 2. Baixar do Servidor (Last-Write-Wins)
  Future<void> _pullFromApi() async {
    try {
      // final response = await http.get(Uri.parse(_baseUrl));
      // final serverTasks = ... decode response ...

      // Lógica LWW (Conceitual para a aula):
      /*
      for (var serverTask in serverTasks) {
        final localTask = await DatabaseService.instance.read(serverTask.id);
        
        if (localTask == null) {
           await DatabaseService.instance.create(serverTask); // Insere local
        } else {
           // Conflito: Quem é mais recente?
           final serverTime = DateTime.parse(serverTask.updatedAt);
           final localTime = DateTime.parse(localTask.updatedAt);
           
           if (serverTime.isAfter(localTime)) {
             // Servidor ganha: Sobrescreve local
             await DatabaseService.instance.update(serverTask);
           } else {
             // Local ganha: (Já está na fila ou será enviado no próximo push)
           }
        }
      }
      */
      print('🔄 Dados baixados e conflitos resolvidos (Simulado)');
    } catch (e) {
      print('Erro no pull: $e');
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
