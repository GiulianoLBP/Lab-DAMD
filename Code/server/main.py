from flask import Flask, jsonify
from app.database import init_db
from app.controllers.entrega_controller import entrega_bp

app = Flask(__name__)
app.register_blueprint(entrega_bp)


@app.errorhandler(404)
def not_found(_e):
    return jsonify({'error': 'Recurso não encontrado'}), 404


@app.errorhandler(405)
def method_not_allowed(_e):
    return jsonify({'error': 'Método não permitido'}), 405


@app.errorhandler(500)
def internal_error(_e):
    return jsonify({'error': 'Erro interno do servidor'}), 500


if __name__ == '__main__':
    init_db()
    app.run(debug=True)
