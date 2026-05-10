from enum import Enum
from dataclasses import dataclass
from typing import Optional


class StatusEntrega(Enum):
    PENDENTE = 'pendente'
    ACEITO = 'aceito'
    EM_TRANSITO = 'em_transito'
    CONCLUIDO = 'concluido'
    CANCELADO = 'cancelado'


@dataclass
class Entrega:
    descricao: str
    origem: str
    destino: str
    cliente_id: str
    status: str = StatusEntrega.PENDENTE.value
    id: Optional[int] = None
    criado_em: Optional[str] = None
    atualizado_em: Optional[str] = None

    def to_dict(self):
        return {
            'id': self.id,
            'descricao': self.descricao,
            'origem': self.origem,
            'destino': self.destino,
            'status': self.status,
            'cliente_id': self.cliente_id,
            'criado_em': self.criado_em,
            'atualizado_em': self.atualizado_em,
        }
