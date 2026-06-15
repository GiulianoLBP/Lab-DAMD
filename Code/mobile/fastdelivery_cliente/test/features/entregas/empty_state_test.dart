import 'package:fastdelivery_cliente/features/entregas/presentation/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FL08 estado vazio mostra título e descrição', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            titulo: 'Nenhuma entrega ainda',
            descricao: 'Crie a primeira solicitação.',
          ),
        ),
      ),
    );

    expect(find.text('Nenhuma entrega ainda'), findsOneWidget);
    expect(find.text('Crie a primeira solicitação.'), findsOneWidget);
  });
}
