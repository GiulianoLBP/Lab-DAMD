import 'package:flutter/material.dart';

import '../../application/entrega_controller.dart';
import '../../data/entrega_api_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/entrega_card.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import 'entrega_detail_screen.dart';
import 'entrega_form_screen.dart';

/// Tela inicial: lista as entregas do cliente, com carregamento, vazio, erro e
/// polling automático a cada 5 segundos enquanto visível.
class EntregaListScreen extends StatefulWidget {
  const EntregaListScreen({super.key, required this.service});

  final EntregaApiService service;

  @override
  State<EntregaListScreen> createState() => _EntregaListScreenState();
}

class _EntregaListScreenState extends State<EntregaListScreen> {
  late final EntregaListController _controller = EntregaListController(
    widget.service,
  );

  @override
  void initState() {
    super.initState();
    _controller.carregar();
    _controller.iniciarPolling();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _abrirNova() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EntregaFormScreen(service: widget.service),
      ),
    );
    // De volta do formulário, recarrega para refletir a nova entrega na hora.
    await _controller.carregar();
  }

  void _abrirDetalhe(int id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            EntregaDetailScreen(service: widget.service, entregaId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FastDelivery'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: () => _controller.carregar(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirNova,
        icon: const Icon(Icons.add),
        label: const Text('Nova entrega'),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final entregas = _controller.entregas;

          if (_controller.carregando && entregas.isEmpty) {
            return const LoadingView(mensagem: 'Carregando entregas...');
          }
          if (_controller.erro != null && entregas.isEmpty) {
            return ErrorView(
              mensagem: _controller.erro!,
              onRetry: () => _controller.carregar(),
            );
          }
          if (entregas.isEmpty) {
            return const EmptyState(
              titulo: 'Nenhuma entrega ainda',
              descricao:
                  'Toque em "Nova entrega" para criar a primeira solicitação.',
              icone: Icons.local_shipping_outlined,
            );
          }

          return RefreshIndicator(
            onRefresh: _controller.carregar,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: entregas.length,
              itemBuilder: (context, index) {
                final entrega = entregas[index];
                return EntregaCard(
                  entrega: entrega,
                  onTap: () => _abrirDetalhe(entrega.id),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
