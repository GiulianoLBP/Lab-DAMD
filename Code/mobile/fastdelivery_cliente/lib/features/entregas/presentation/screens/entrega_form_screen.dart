import 'package:flutter/material.dart';

import '../../../../core/http/api_exception.dart';
import '../../data/entrega_api_service.dart';
import '../../domain/entrega.dart';

/// Tela de criação de uma nova entrega.
///
/// Valida campos obrigatórios, desabilita o envio enquanto a requisição está em
/// andamento e exibe a mensagem de erro do backend quando houver. O
/// `cliente_id` é fixo (demo) e o `status` não é enviado — o backend define
/// `pendente`.
class EntregaFormScreen extends StatefulWidget {
  const EntregaFormScreen({super.key, required this.service, this.onCreated});

  final EntregaApiService service;

  /// Callback opcional chamado após criar (usado em testes). Quando ausente, a
  /// tela mostra um SnackBar e volta para a lista retornando a entrega criada.
  final ValueChanged<Entrega>? onCreated;

  @override
  State<EntregaFormScreen> createState() => _EntregaFormScreenState();
}

class _EntregaFormScreenState extends State<EntregaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoCtrl = TextEditingController();
  final _origemCtrl = TextEditingController();
  final _destinoCtrl = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    _origemCtrl.dispose();
    _destinoCtrl.dispose();
    super.dispose();
  }

  String? _obrigatorio(String? valor, String campo) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Informe $campo';
    }
    return null;
  }

  Future<void> _enviar() async {
    if (_enviando) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _enviando = true);
    try {
      final entrega = await widget.service.criar(
        descricao: _descricaoCtrl.text.trim(),
        origem: _origemCtrl.text.trim(),
        destino: _destinoCtrl.text.trim(),
      );
      if (!mounted) {
        return;
      }
      final onCreated = widget.onCreated;
      if (onCreated != null) {
        onCreated(entrega);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Entrega #${entrega.id} criada com sucesso')),
      );
      Navigator.of(context).pop(entrega);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova entrega')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _campo(
                  chave: const Key('campo_descricao'),
                  controller: _descricaoCtrl,
                  rotulo: 'Descrição',
                  hint: 'O que será entregue?',
                  icone: Icons.description_outlined,
                  validator: (v) => _obrigatorio(v, 'a descrição'),
                ),
                const SizedBox(height: 16),
                _campo(
                  chave: const Key('campo_origem'),
                  controller: _origemCtrl,
                  rotulo: 'Origem',
                  hint: 'Endereço de coleta',
                  icone: Icons.trip_origin,
                  validator: (v) => _obrigatorio(v, 'a origem'),
                ),
                const SizedBox(height: 16),
                _campo(
                  chave: const Key('campo_destino'),
                  controller: _destinoCtrl,
                  rotulo: 'Destino',
                  hint: 'Endereço de entrega',
                  icone: Icons.place_outlined,
                  validator: (v) => _obrigatorio(v, 'o destino'),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  key: const Key('btn_enviar'),
                  onPressed: _enviando ? null : _enviar,
                  icon: _enviando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(_enviando ? 'Enviando...' : 'Criar entrega'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _campo({
    required Key chave,
    required TextEditingController controller,
    required String rotulo,
    required String hint,
    required IconData icone,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      key: chave,
      controller: controller,
      enabled: !_enviando,
      textInputAction: TextInputAction.next,
      validator: validator,
      decoration: InputDecoration(
        labelText: rotulo,
        hintText: hint,
        prefixIcon: Icon(icone),
        border: const OutlineInputBorder(),
      ),
    );
  }
}
