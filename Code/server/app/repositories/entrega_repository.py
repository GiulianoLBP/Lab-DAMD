from typing import List, Optional
from app.database import get_connection
from app.domain.models import Entrega


class EntregaRepository:

    def create(self, entrega: Entrega) -> Entrega:
        conn = get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(
                '''INSERT INTO entregas (descricao, origem, destino, status, cliente_id)
                   VALUES (?, ?, ?, ?, ?)''',
                (entrega.descricao, entrega.origem, entrega.destino,
                 entrega.status, entrega.cliente_id),
            )
            conn.commit()
            return self._fetch_by_id(cursor.lastrowid, conn)
        finally:
            conn.close()

    def get_by_id(self, entrega_id: int) -> Optional[Entrega]:
        conn = get_connection()
        try:
            return self._fetch_by_id(entrega_id, conn)
        finally:
            conn.close()

    def list_all(self, status: Optional[str] = None) -> List[Entrega]:
        conn = get_connection()
        try:
            cursor = conn.cursor()
            if status:
                cursor.execute('SELECT * FROM entregas WHERE status = ?', (status,))
            else:
                cursor.execute('SELECT * FROM entregas')
            return [self._row_to_entrega(row) for row in cursor.fetchall()]
        finally:
            conn.close()

    def update_status(self, entrega_id: int, new_status: str) -> Optional[Entrega]:
        conn = get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(
                '''UPDATE entregas
                   SET status = ?, atualizado_em = datetime('now')
                   WHERE id = ?''',
                (new_status, entrega_id),
            )
            conn.commit()
            if cursor.rowcount == 0:
                return None
            return self._fetch_by_id(entrega_id, conn)
        finally:
            conn.close()

    def _fetch_by_id(self, entrega_id: int, conn) -> Optional[Entrega]:
        cursor = conn.cursor()
        cursor.execute('SELECT * FROM entregas WHERE id = ?', (entrega_id,))
        row = cursor.fetchone()
        return self._row_to_entrega(row) if row else None

    @staticmethod
    def _row_to_entrega(row) -> Entrega:
        return Entrega(
            id=row['id'],
            descricao=row['descricao'],
            origem=row['origem'],
            destino=row['destino'],
            status=row['status'],
            cliente_id=row['cliente_id'],
            criado_em=row['criado_em'],
            atualizado_em=row['atualizado_em'],
        )
