from __future__ import annotations

import json
from datetime import datetime
from typing import Optional

from app.database import get_connection


class EventoProcessadoRepository:

    def registrar(
        self,
        evento_id: str,
        tipo: str,
        entrega_id: Optional[int],
        mensagem: str,
        payload: dict,
        limite: int,
    ) -> bool:
        conn = get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(
                '''INSERT OR IGNORE INTO eventos_processados
                   (evento_id, tipo, entrega_id, mensagem, processado_em, payload)
                   VALUES (?, ?, ?, ?, ?, ?)''',
                (
                    evento_id,
                    tipo,
                    entrega_id,
                    mensagem,
                    datetime.now().strftime('%Y-%m-%dT%H:%M:%S'),
                    json.dumps(payload, ensure_ascii=False),
                ),
            )
            inserido = cursor.rowcount > 0
            cursor.execute(
                '''DELETE FROM eventos_processados
                   WHERE rowid NOT IN (
                       SELECT rowid
                       FROM eventos_processados
                       ORDER BY processado_em DESC, rowid DESC
                       LIMIT ?
                   )''',
                (limite,),
            )
            conn.commit()
            return inserido
        finally:
            conn.close()

    def listar(self, ultimos: Optional[int] = None) -> list[dict]:
        conn = get_connection()
        try:
            cursor = conn.cursor()
            query = '''SELECT evento_id, tipo, entrega_id, mensagem,
                              processado_em, payload
                       FROM eventos_processados
                       ORDER BY processado_em DESC, rowid DESC'''
            params: tuple = ()
            if ultimos is not None and ultimos > 0:
                query += ' LIMIT ?'
                params = (ultimos,)
            cursor.execute(query, params)
            eventos = [self._row_to_dict(row) for row in cursor.fetchall()]
            eventos.reverse()
            return eventos
        finally:
            conn.close()

    @staticmethod
    def _row_to_dict(row) -> dict:
        return {
            'evento_id': row['evento_id'],
            'tipo': row['tipo'],
            'entrega_id': row['entrega_id'],
            'mensagem': row['mensagem'],
            'processado_em': row['processado_em'],
            'payload': json.loads(row['payload']),
        }
