from flask import Blueprint, request, jsonify
from app.repositories.entrega_repository import EntregaRepository
from app.use_cases.entrega_use_cases import EntregaUseCases, StatusInvalido, EntregaNaoEncontrada
from app.mom.consumer import obter_historico

entrega_bp = Blueprint('entregas', __name__)

# O event_producer será injetado externamente (ver main.py)
_use_cases: EntregaUseCases = None  # type: ignore[assignment]


def init_use_cases(use_cases: EntregaUseCases) -> None:
    """Injeta o caso de uso configurado (com event_producer)."""
    global _use_cases
    _use_cases = use_cases


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


@entrega_bp.route('/entregas', methods=['GET'])
def listar_entregas():
    status = request.args.get('status', default=None)
    try:
        entregas = _use_cases.listar_entregas(status)
        return jsonify([e.to_dict() for e in entregas]), 200
    except StatusInvalido:
        return jsonify({'error': 'Status inválido'}), 400


@entrega_bp.route('/entregas/<int:entrega_id>', methods=['GET'])
def obter_entrega(entrega_id):
    try:
        entrega = _use_cases.buscar_entrega(entrega_id)
        return jsonify(entrega.to_dict()), 200
    except EntregaNaoEncontrada:
        return jsonify({'error': 'Entrega não encontrada'}), 404


@entrega_bp.route('/entregas/<int:entrega_id>/status', methods=['PATCH'])
def atualizar_status(entrega_id):
    dados = request.get_json(silent=True)
    if not dados or 'status' not in dados:
        return jsonify({'error': 'Campo "status" obrigatório'}), 400
    try:
        entrega = _use_cases.atualizar_status(entrega_id, dados['status'])
        return jsonify(entrega.to_dict()), 200
    except StatusInvalido:
        return jsonify({'error': 'Status inválido'}), 400
    except EntregaNaoEncontrada:
        return jsonify({'error': 'Entrega não encontrada'}), 404


# ─── Rota auxiliar: histórico de eventos MOM ───────────────────────────


@entrega_bp.route('/eventos', methods=['GET'])
def listar_eventos():
    """Retorna o histórico de eventos processados pelo consumidor MOM."""
    ultimos = request.args.get('ultimos', default=None, type=int)
    return jsonify(obter_historico(ultimos)), 200
