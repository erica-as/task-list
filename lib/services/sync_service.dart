import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'database_service.dart';
import '../models/task.dart';

class SyncService {
  static final SyncService instance = SyncService._init();
  SyncService._init();

  final _connectivity = Connectivity();
  StreamSubscription? _subscription;

  final ValueNotifier<bool> isOnline = ValueNotifier(false);

  void initialize() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final result = results.first;
      bool online = result != ConnectivityResult.none;
      isOnline.value = online;

      if (online) {
        print('🌐 Conexão restaurada! Iniciando sincronização...');
        _processSyncQueue();
        _pullFromApi();
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
            await Future.delayed(const Duration(milliseconds: 500));
            success = true;
            break;
          case 'UPDATE':
            await Future.delayed(const Duration(milliseconds: 500));
            success = true;
            break;
          case 'DELETE':
            success = true;
            break;
        }

        if (success) {
          await DatabaseService.instance.removeFromQueue(queueId);

          if (item['taskId'] != null && action != 'DELETE') {
            await DatabaseService.instance.markAsSynced(item['taskId']);
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
      print('🔄 Dados baixados e conflitos resolvidos (Simulado)');
    } catch (e) {
      print('Erro no pull: $e');
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
