import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/entregas/data/entrega_api_service.dart';
import 'features/entregas/presentation/screens/entrega_list_screen.dart';

/// Raiz do app. Cria (e descarta) um único [EntregaApiService] compartilhado
/// por todas as telas. O serviço pode ser injetado para testes.
class FastDeliveryApp extends StatefulWidget {
  const FastDeliveryApp({super.key, this.service});

  final EntregaApiService? service;

  @override
  State<FastDeliveryApp> createState() => _FastDeliveryAppState();
}

class _FastDeliveryAppState extends State<FastDeliveryApp> {
  late final EntregaApiService _service = widget.service ?? EntregaApiService();
  late final bool _possuiServico = widget.service == null;

  @override
  void dispose() {
    // Só fecha o cliente HTTP se nós o criamos (não quando foi injetado).
    if (_possuiServico) {
      _service.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FastDelivery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: EntregaListScreen(service: _service),
    );
  }
}
