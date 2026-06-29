import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entrega.dart';
import 'status_badge.dart';

/// Card compacto de uma entrega na lista: descrição, rota resumida, status e
/// data de atualização (quando disponível). Cópia do widget do app cliente.
class EntregaCard extends StatelessWidget {
  const EntregaCard({super.key, required this.entrega, this.onTap});

  final Entrega entrega;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Forma, borda, elevação e margem vêm do CardTheme central (AppTheme).
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entrega.descricao.isEmpty
                          ? 'Entrega #${entrega.id}'
                          : entrega.descricao,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: entrega.status),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _LinhaRota(origem: entrega.origem, destino: entrega.destino),
              if (entrega.atualizadoEm != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Atualizada em ${entrega.atualizadoEm}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LinhaRota extends StatelessWidget {
  const _LinhaRota({required this.origem, required this.destino});

  final String origem;
  final String destino;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.bodyMedium;
    return Row(
      children: [
        const Icon(Icons.trip_origin, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            origem.isEmpty ? '—' : origem,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: estilo,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.arrow_forward, size: 16),
        ),
        const Icon(Icons.place_outlined, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            destino.isEmpty ? '—' : destino,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: estilo,
          ),
        ),
      ],
    );
  }
}
