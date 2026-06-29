import 'package:flutter/material.dart';

import '../../data/entrega_api_service.dart';
import '../../data/eventos_realtime_service.dart';
import '../widgets/realtime_indicator.dart';
import 'andamento_screen.dart';
import 'pendentes_screen.dart';

/// Shell do app do prestador: alterna entre "Pendentes" e "Em andamento" por uma
/// barra inferior. Usa [IndexedStack] para manter os dois controladores vivos
/// (ambos continuam recebendo eventos do MOM mesmo na aba inativa).
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.service,
    required this.realtime,
  });

  final EntregaApiService service;
  final EventosRealtimeService realtime;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indice = 0;

  late final List<Widget> _telas = <Widget>[
    PendentesScreen(service: widget.service, realtime: widget.realtime),
    AndamentoScreen(service: widget.service, realtime: widget.realtime),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FastDelivery — Prestador'),
        actions: [RealtimeIndicator(realtime: widget.realtime)],
      ),
      body: IndexedStack(index: _indice, children: _telas),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: 'Pendentes',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'Em andamento',
          ),
        ],
      ),
    );
  }
}
