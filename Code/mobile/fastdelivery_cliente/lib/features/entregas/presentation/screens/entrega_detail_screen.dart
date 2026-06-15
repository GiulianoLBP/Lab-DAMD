import 'package:flutter/material.dart';

import '../../application/entrega_controller.dart';
import '../../data/entrega_api_service.dart';
import '../../domain/entrega.dart';
import '../../domain/status_entrega.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/status_badge.dart';

/// Tela de detalhes de uma entrega: mostra todos os campos, uma linha de
/// progresso do status e atualiza sozinha por polling. O botão "Cancelar" só
/// aparece quando o status é `pendente`.
class EntregaDetailScreen extends StatefulWidget {
  const EntregaDetailScreen({
    super.key,
    required this.service,
    required this.entregaId,
  });

  final EntregaApiService service;
  final int entregaId;

  @override
  State<EntregaDetailScreen> createState() => _EntregaDetailScreenState();
}

class _EntregaDetailScreenState extends State<EntregaDetailScreen> {
  late final EntregaDetailController _controller = EntregaDetailController(
    widget.service,
    entregaId: widget.entregaId,
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

  Future<void> _confirmarCancelamento() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar entrega?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancelar entrega'),
          ),
        ],
      ),
    );
    if (confirmar != true) {
      return;
    }
    final ok = await _controller.cancelar();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Entrega cancelada'
              : (_controller.erro ?? 'Não foi possível cancelar'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Entrega #${widget.entregaId}')),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final entrega = _controller.entrega;

          if (_controller.carregando && entrega == null) {
            return const LoadingView(mensagem: 'Carregando detalhes...');
          }
          if (_controller.erro != null && entrega == null) {
            return ErrorView(
              mensagem: _controller.erro!,
              onRetry: () => _controller.carregar(),
            );
          }
          if (entrega == null) {
            return const LoadingView();
          }

          final podeCancelar = entrega.statusEnum?.podeCancelar ?? false;
          return _Detalhe(
            entrega: entrega,
            cancelando: _controller.cancelando,
            aviso: _controller.avisoPolling,
            onCancelar: podeCancelar ? _confirmarCancelamento : null,
          );
        },
      ),
    );
  }
}

class _Detalhe extends StatelessWidget {
  const _Detalhe({
    required this.entrega,
    required this.cancelando,
    required this.onCancelar,
    this.aviso,
  });

  final Entrega entrega;
  final bool cancelando;
  final VoidCallback? onCancelar;
  final String? aviso;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                entrega.descricao.isEmpty
                    ? 'Entrega #${entrega.id}'
                    : entrega.descricao,
                style: theme.textTheme.headlineSmall,
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(status: entrega.status),
          ],
        ),
        if (aviso != null) _AvisoPolling(texto: aviso!),
        const SizedBox(height: 24),
        _StatusTimeline(status: entrega.statusEnum),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        _CampoInfo(
          rotulo: 'Origem',
          valor: entrega.origem,
          icone: Icons.trip_origin,
        ),
        _CampoInfo(
          rotulo: 'Destino',
          valor: entrega.destino,
          icone: Icons.place_outlined,
        ),
        _CampoInfo(
          rotulo: 'Cliente',
          valor: entrega.clienteId,
          icone: Icons.person_outline,
        ),
        _CampoInfo(
          rotulo: 'Criada em',
          valor: entrega.criadoEm ?? '—',
          icone: Icons.schedule,
        ),
        _CampoInfo(
          rotulo: 'Atualizada em',
          valor: entrega.atualizadoEm ?? '—',
          icone: Icons.update,
        ),
        const SizedBox(height: 28),
        if (onCancelar != null)
          FilledButton.tonalIcon(
            onPressed: cancelando ? null : onCancelar,
            icon: cancelando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cancel_outlined),
            label: Text(cancelando ? 'Cancelando...' : 'Cancelar entrega'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          )
        else
          Text(
            'Apenas entregas pendentes podem ser canceladas pelo cliente.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
      ],
    );
  }
}

/// Aviso discreto de falha temporária no polling (mantém os dados na tela).
class _AvisoPolling extends StatelessWidget {
  const _AvisoPolling({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(Icons.sync_problem, size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha de progresso simples: pendente → aceito → em_transito → concluido.
/// `cancelado` é mostrado como estado final alternativo.
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.status});

  final StatusEntrega? status;

  @override
  Widget build(BuildContext context) {
    if (status == StatusEntrega.cancelado) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFCE0E0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(Icons.cancel, color: Color(0xFF9B1C1C)),
            SizedBox(width: 8),
            Text('Entrega cancelada'),
          ],
        ),
      );
    }

    final etapas = StatusEntrega.fluxoPrincipal;
    final atual = status == null ? -1 : etapas.indexOf(status!);
    return Column(
      children: [
        for (int i = 0; i < etapas.length; i++)
          _EtapaLinha(
            rotulo: etapas[i].rotulo,
            concluida: i <= atual,
            atual: i == atual,
          ),
      ],
    );
  }
}

class _EtapaLinha extends StatelessWidget {
  const _EtapaLinha({
    required this.rotulo,
    required this.concluida,
    required this.atual,
  });

  final String rotulo;
  final bool concluida;
  final bool atual;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cor = concluida
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            concluida ? Icons.check_circle : Icons.radio_button_unchecked,
            color: cor,
            size: 22,
          ),
          const SizedBox(width: 12),
          Text(
            rotulo,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: atual ? FontWeight.w700 : FontWeight.w400,
              color: concluida
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _CampoInfo extends StatelessWidget {
  const _CampoInfo({
    required this.rotulo,
    required this.valor,
    required this.icone,
  });

  final String rotulo;
  final String valor;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 20, color: theme.colorScheme.outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rotulo,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valor.isEmpty ? '—' : valor,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
