from flask import Blueprint, request, jsonify
from app.repositories.entrega_repository import EntregaRepository
from app.use_cases.entrega_use_cases import EntregaUseCases, StatusInvalido, EntregaNaoEncontrada

entrega_bp = Blueprint('entregas', __name__)

_use_cases = EntregaUseCases(EntregaRepository())


@entrega_bp.route('/entregas', methods=['POST'])
def criar_entrega():
    dados = request.get_json(silent=True)
    if not dados:
        return jsonify({'error': 'Body JSON obrigatório'}), 400
    try:
        entrega = _use_cases.criar_entrega(dados)
        return jsonify(entrega.to_dict()), 201
    except ValueError as e:
        return jsonify({'error': str(e)}), 400
