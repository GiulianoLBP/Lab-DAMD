import 'package:flutter/material.dart';

import '../../application/detalhe_controller.dart';
import '../../data/entrega_api_service.dart';
import '../../data/eventos_realtime_service.dart';
import '../../domain/entrega.dart';
import '../../domain/status_entrega.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/status_badge.dart';

/// (b) Detalhe da solicitação, com as ações do prestador.
///
/// Atualiza sozinha pelos eventos do MOM (WebSocket). As ações dependem do
/// status: pendente → Aceitar/Recusar; aceito/em_transito → avançar status;
/// concluido/cancelado → somente leitura.
class DetalheScreen extends StatefulWidget {
  const DetalheScreen({
    super.key,
    required this.service,
    required this.realtime,
    required this.entregaId,
  });

  final EntregaApiService service;
  final EventosRealtimeService realtime;
  final int entregaId;

  @override
  State<DetalheScreen> createState() => _DetalheScreenState();
}

class _DetalheScreenState extends State<DetalheScreen> {
  late final DetalheController _controller = DetalheController(
    widget.service,
    widget.realtime,
    entregaId: widget.entregaId,
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

  Future<void> _aceitar() async {
    final ok = await _controller.aceitar();
    _feedback(ok, sucesso: 'Solicitação aceita');
  }

  Future<void> _avancar(String rotulo) async {
    final ok = await _controller.avancar();
    _feedback(ok, sucesso: '$rotulo: feito');
  }

  Future<void> _recusar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recusar solicitação?'),
        content: const Text(
          'A solicitação será cancelada e o cliente verá a atualização.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Recusar'),
          ),
        ],
      ),
    );
    if (confirmar != true) {
      return;
    }
    final ok = await _controller.recusar();
    _feedback(ok, sucesso: 'Solicitação recusada');
  }

  void _feedback(bool ok, {required String sucesso}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? sucesso : (_controller.erro ?? 'Não foi possível concluir a ação'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Solicitação #${widget.entregaId}')),
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
              onRetry: _controller.carregar,
            );
          }
          if (entrega == null) {
            return const LoadingView();
          }

          return _Detalhe(
            entrega: entrega,
            executando: _controller.executandoAcao,
            onAceitar: _aceitar,
            onRecusar: _recusar,
            onAvancar: _avancar,
          );
        },
      ),
    );
  }
}

class _Detalhe extends StatelessWidget {
  const _Detalhe({
    required this.entrega,
    required this.executando,
    required this.onAceitar,
    required this.onRecusar,
    required this.onAvancar,
  });

  final Entrega entrega;
  final bool executando;
  final VoidCallback onAceitar;
  final VoidCallback onRecusar;
  final void Function(String rotulo) onAvancar;

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
        _Acoes(
          status: entrega.statusEnum,
          executando: executando,
          onAceitar: onAceitar,
          onRecusar: onRecusar,
          onAvancar: onAvancar,
        ),
      ],
    );
  }
}

/// Bloco de ações do prestador, conforme o status atual.
class _Acoes extends StatelessWidget {
  const _Acoes({
    required this.status,
    required this.executando,
    required this.onAceitar,
    required this.onRecusar,
    required this.onAvancar,
  });

  final StatusEntrega? status;
  final bool executando;
  final VoidCallback onAceitar;
  final VoidCallback onRecusar;
  final void Function(String rotulo) onAvancar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (status?.podeDecidir ?? false) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: executando ? null : onRecusar,
              icon: const Icon(Icons.close),
              label: const Text('Recusar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: executando ? null : onAceitar,
              icon: executando
                  ? const _Spinner()
                  : const Icon(Icons.check),
              label: const Text('Aceitar'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      );
    }

    final rotuloAvancar = status?.rotuloAvancar;
    if (rotuloAvancar != null) {
      return FilledButton.icon(
        onPressed: executando ? null : () => onAvancar(rotuloAvancar),
        icon: executando ? const _Spinner() : const Icon(Icons.arrow_forward),
        label: Text(rotuloAvancar),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      );
    }

    // concluido / cancelado: somente leitura.
    final encerrada = status == StatusEntrega.concluido
        ? 'Entrega concluída.'
        : 'Solicitação encerrada (recusada/cancelada).';
    return Text(
      encerrada,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.outline,
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

/// Linha de progresso: pendente → aceito → em_transito → concluido.
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
            Text('Solicitação recusada/cancelada'),
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
