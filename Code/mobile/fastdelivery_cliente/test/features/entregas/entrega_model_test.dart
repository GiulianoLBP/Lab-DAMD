import 'package:fastdelivery_cliente/features/entregas/domain/entrega.dart';
import 'package:fastdelivery_cliente/features/entregas/domain/status_entrega.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Entrega.fromJson', () {
    test('FL01 monta o modelo a partir de JSON completo', () {
      final entrega = Entrega.fromJson(<String, dynamic>{
        'id': 7,
        'descricao': 'Pacote',
        'origem': 'Rua A, 100',
        'destino': 'Rua B, 200',
        'status': 'pendente',
        'cliente_id': 'cliente-demo-001',
        'criado_em': '2026-06-14T10:00:00',
        'atualizado_em': '2026-06-14T10:05:00',
      });

      expect(entrega.id, 7);
      expect(entrega.descricao, 'Pacote');
      expect(entrega.origem, 'Rua A, 100');
      expect(entrega.destino, 'Rua B, 200');
      expect(entrega.status, 'pendente');
      expect(entrega.clienteId, 'cliente-demo-001');
      expect(entrega.criadoEm, '2026-06-14T10:00:00');
      expect(entrega.atualizadoEm, '2026-06-14T10:05:00');
      expect(entrega.statusEnum, StatusEntrega.pendente);
    });

    test('FL02 usa fallback claro quando campos textuais estão ausentes', () {
      final entrega = Entrega.fromJson(<String, dynamic>{
        'id': 1,
        'status': 'aceito',
        'cliente_id': 'cliente-demo-001',
      });

      expect(entrega.descricao, '');
      expect(entrega.origem, '');
      expect(entrega.destino, '');
      expect(entrega.criadoEm, isNull);
      expect(entrega.atualizadoEm, isNull);
      expect(entrega.statusEnum, StatusEntrega.aceito);
    });

    test('FL02 lança FormatException quando o id é ausente/ inválido', () {
      expect(
        () => Entrega.fromJson(<String, dynamic>{'descricao': 'sem id'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('statusEnum é null para status desconhecido', () {
      final entrega = Entrega.fromJson(<String, dynamic>{
        'id': 2,
        'status': 'teleportando',
        'cliente_id': 'c',
      });

      expect(entrega.statusEnum, isNull);
    });
  });
}
