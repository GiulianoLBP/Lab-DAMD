import 'package:fastdelivery_cliente/features/entregas/domain/status_entrega.dart';
import 'package:fastdelivery_cliente/features/entregas/presentation/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FL07 badge mostra o rótulo correto de cada status', (
    tester,
  ) async {
    for (final status in StatusEntrega.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StatusBadge(status: status.valor)),
        ),
      );
      expect(
        find.text(status.rotulo),
        findsOneWidget,
        reason: 'status ${status.valor}',
      );
    }
  });

  testWidgets('FL07 badge com status desconhecido não quebra', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StatusBadge(status: 'xpto')),
      ),
    );

    expect(find.text('xpto'), findsOneWidget);
  });
}
