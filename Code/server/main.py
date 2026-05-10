from flask import Flask
from app.database import init_db
from app.controllers.entrega_controller import entrega_bp

app = Flask(__name__)
app.register_blueprint(entrega_bp)

if __name__ == '__main__':
    init_db()
    app.run(debug=True)
