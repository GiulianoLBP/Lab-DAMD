import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/pendentes_controller.dart';
import '../../data/entrega_api_service.dart';
import '../../data/eventos_realtime_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/entrega_card.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import 'detalhe_screen.dart';

/// (a) Lista de solicitações PENDENTES.
///
/// Carrega via REST e recebe novas solicitações AO VIVO (WebSocket): ao chegar
/// `entrega.criada`, a lista atualiza sozinha e um aviso (snackbar) é exibido —
/// sem o prestador precisar atualizar a tela.
class PendentesScreen extends StatefulWidget {
  const PendentesScreen({
    super.key,
    required this.service,
    required this.realtime,
  });

  final EntregaApiService service;
  final EventosRealtimeService realtime;

  @override
  State<PendentesScreen> createState() => _PendentesScreenState();
}

class _PendentesScreenState extends State<PendentesScreen> {
  late final PendentesController _controller = PendentesController(
    widget.service,
    widget.realtime,
  );
  StreamSubscription<String>? _notSub;

  @override
  void initState() {
    super.initState();
    _controller.iniciar();
    _notSub = _controller.notificacoes.listen(_mostrarNotificacao);
  }

  void _mostrarNotificacao(String mensagem) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mensagem)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _notSub?.cancel();
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
          return const LoadingView(mensagem: 'Carregando solicitações...');
        }
        if (_controller.erro != null && itens.isEmpty) {
          return ErrorView(
            mensagem: _controller.erro!,
            onRetry: _controller.carregar,
          );
        }
        if (itens.isEmpty) {
          return const EmptyState(
            titulo: 'Nenhuma solicitação pendente',
            descricao: 'Novas solicitações aparecem aqui automaticamente.',
            icone: Icons.inbox_outlined,
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
