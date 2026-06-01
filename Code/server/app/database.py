import os
import sqlite3

DB_PATH = 'entregas.db'


def get_connection():
    conn = sqlite3.connect(os.environ.get('DATABASE_PATH', DB_PATH))
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute('''
        CREATE TABLE IF NOT EXISTS entregas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            descricao TEXT NOT NULL,
            origem TEXT NOT NULL,
            destino TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pendente',
            cliente_id TEXT NOT NULL,
            criado_em TEXT NOT NULL DEFAULT (datetime('now')),
            atualizado_em TEXT NOT NULL DEFAULT (datetime('now'))
        )
    ''')

    cursor.execute('''
        CREATE TABLE IF NOT EXISTS eventos_processados (
            evento_id TEXT PRIMARY KEY,
            tipo TEXT NOT NULL,
            entrega_id INTEGER,
            mensagem TEXT NOT NULL,
            processado_em TEXT NOT NULL,
            payload TEXT NOT NULL
        )
    ''')

    conn.commit()
    conn.close()
