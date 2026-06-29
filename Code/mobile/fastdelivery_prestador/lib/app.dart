import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/entregas/data/entrega_api_service.dart';
import 'features/entregas/data/eventos_realtime_service.dart';
import 'features/entregas/presentation/screens/home_screen.dart';

/// Raiz do app do prestador. Cria (e descarta) um único [EntregaApiService] e um
/// único [EventosRealtimeService] compartilhados por todas as telas. Ambos podem
/// ser injetados para testes. A conexão em tempo real é aberta no início.
class PrestadorApp extends StatefulWidget {
  const PrestadorApp({super.key, this.service, this.realtime});

  final EntregaApiService? service;
  final EventosRealtimeService? realtime;

  @override
  State<PrestadorApp> createState() => _PrestadorAppState();
}

class _PrestadorAppState extends State<PrestadorApp> {
  late final EntregaApiService _service = widget.service ?? EntregaApiService();
  late final EventosRealtimeService _realtime =
      widget.realtime ?? EventosRealtimeService();
  // Só descarta o que NÓS criamos (não o que foi injetado em testes).
  late final bool _possuiService = widget.service == null;
  late final bool _possuiRealtime = widget.realtime == null;

  @override
  void initState() {
    super.initState();
    _realtime.conectar();
  }

  @override
  void dispose() {
    if (_possuiRealtime) {
      _realtime.dispose();
    }
    if (_possuiService) {
      _service.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FastDelivery Prestador',
      debugShowCheckedModeBanner: false,
      // Mesmo tema central do app cliente (coerência visual entre os dois apps).
      theme: AppTheme.light,
      home: HomeScreen(service: _service, realtime: _realtime),
    );
  }
}
