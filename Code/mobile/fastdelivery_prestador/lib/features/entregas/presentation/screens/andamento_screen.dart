import 'package:flutter/material.dart';

import '../../application/andamento_controller.dart';
import '../../data/entrega_api_service.dart';
import '../../data/eventos_realtime_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/entrega_card.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import 'detalhe_screen.dart';

/// (c) Acompanhamento das solicitações EM ANDAMENTO (aceitas/em trânsito).
///
/// Carrega via REST e reflete AO VIVO as mudanças de status (WebSocket): quando
/// uma entrega avança ou é concluída, a lista se ajusta sem ação manual.
class AndamentoScreen extends StatefulWidget {
  const AndamentoScreen({
    super.key,
    required this.service,
    required this.realtime,
  });

  final EntregaApiService service;
  final EventosRealtimeService realtime;

  @override
  State<AndamentoScreen> createState() => _AndamentoScreenState();
}

class _AndamentoScreenState extends State<AndamentoScreen> {
  late final AndamentoController _controller = AndamentoController(
    widget.service,
    widget.realtime,
  );

  @override
  void initState() {
    super.initState();
    _controller.iniciar();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _abrirDetalhe(int id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetalheScreen(
          service: widget.service,
          realtime: widget.realtime,
          entregaId: id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final itens = _controller.itens;

        if (_controller.carregando && itens.isEmpty) {
          return const LoadingView(mensagem: 'Carregando entregas...');
        }
        if (_controller.erro != null && itens.isEmpty) {
          return ErrorView(
            mensagem: _controller.erro!,
            onRetry: _controller.carregar,
          );
        }
        if (itens.isEmpty) {
          return const EmptyState(
            titulo: 'Nada em andamento',
            descricao: 'Solicitações que você aceitar aparecem aqui.',
            icone: Icons.local_shipping_outlined,
          );
        }

        return RefreshIndicator(
          onRefresh: _controller.carregar,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: itens.length,
            itemBuilder: (context, index) {
              final entrega = itens[index];
              return EntregaCard(
                entrega: entrega,
                onTap: () => _abrirDetalhe(entrega.id),
              );
            },
          ),
        );
      },
    );
  }
}
