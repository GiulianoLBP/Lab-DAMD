import 'package:flutter/material.dart';

/// Estado vazio genérico (sem itens), com ícone, título e descrição opcional.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.titulo,
    this.descricao,
    this.icone = Icons.inbox_outlined,
  });

  final String titulo;
  final String? descricao;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(titulo, style: theme.textTheme.titleMedium),
            if (descricao != null) ...[
              const SizedBox(height: 6),
              Text(
                descricao!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
