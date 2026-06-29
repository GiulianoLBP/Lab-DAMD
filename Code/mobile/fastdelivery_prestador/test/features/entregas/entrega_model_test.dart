import 'package:fastdelivery_prestador/features/entregas/domain/entrega.dart';
import 'package:fastdelivery_prestador/features/entregas/domain/status_entrega.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Entrega.fromJson', () {
    test('parseia todos os campos e resolve o statusEnum', () {
      final entrega = Entrega.fromJson(<String, dynamic>{
        'id': 1,
        'descricao': 'Pacote',
        'origem': 'Rua A',
        'destino': 'Rua B',
        'status': 'pendente',
        'cliente_id': 'cliente-1',
        'criado_em': 't1',
        'atualizado_em': 't2',
      });

      expect(entrega.id, 1);
      expect(entrega.descricao, 'Pacote');
      expect(entrega.statusEnum, StatusEntrega.pendente);
    });

    test('aceita id enviado como string', () {
      final entrega = Entrega.fromJson(<String, dynamic>{'id': '5'});
      expect(entrega.id, 5);
    });

    test('lança FormatException quando falta id válido', () {
      expect(
        () => Entrega.fromJson(<String, dynamic>{'descricao': 'x'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('status desconhecido vira null sem quebrar', () {
      final entrega = Entrega.fromJson(<String, dynamic>{
        'id': 1,
        'status': 'voando',
      });
      expect(entrega.status, 'voando');
      expect(entrega.statusEnum, isNull);
    });
  });

  group('StatusEntrega — helpers do prestador', () {
    test('só decide enquanto pendente', () {
      expect(StatusEntrega.pendente.podeDecidir, isTrue);
      expect(StatusEntrega.aceito.podeDecidir, isFalse);
    });

    test('fluxo de avanço: aceito → em_transito → concluido', () {
      expect(StatusEntrega.aceito.proximoStatus, StatusEntrega.emTransito);
      expect(StatusEntrega.emTransito.proximoStatus, StatusEntrega.concluido);
      expect(StatusEntrega.concluido.proximoStatus, isNull);
    });

    test('"em andamento" cobre aceito e em_transito', () {
      expect(StatusEntrega.aceito.emAndamento, isTrue);
      expect(StatusEntrega.emTransito.emAndamento, isTrue);
      expect(StatusEntrega.pendente.emAndamento, isFalse);
      expect(StatusEntrega.concluido.emAndamento, isFalse);
    });
  });
}
