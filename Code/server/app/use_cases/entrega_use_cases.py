from typing import List, Optional
from app.domain.models import Entrega, StatusEntrega
from app.repositories.entrega_repository import EntregaRepository

# Exceções próprias permitem que o controller diferencie 400 de 404 sem acoplar HTTP a esta camada
class EntregaNaoEncontrada(Exception):
    pass


class StatusInvalido(Exception):
    pass


_STATUS_VALIDOS = {s.value for s in StatusEntrega}
_CAMPOS_OBRIGATORIOS = ('descricao', 'origem', 'destino', 'cliente_id')


class EntregaUseCases:

    def __init__(self, repository: EntregaRepository):
        self.repository = repository

    def criar_entrega(self, dados: dict) -> Entrega:
        campos_faltando = [c for c in _CAMPOS_OBRIGATORIOS if not dados.get(c)]
        if campos_faltando:
            raise ValueError(f"Campos obrigatórios ausentes: {', '.join(campos_faltando)}")

        # Rejeita strings compostas só de espaços
        campos_em_branco = [c for c in _CAMPOS_OBRIGATORIOS if not str(dados[c]).strip()]
        if campos_em_branco:
            raise ValueError(f"Campos não podem ser em branco: {', '.join(campos_em_branco)}")

        entrega = Entrega(
            descricao=dados['descricao'].strip(),
            origem=dados['origem'].strip(),
            destino=dados['destino'].strip(),
            cliente_id=dados['cliente_id'].strip(),
            status=StatusEntrega.PENDENTE.value,
        )
        return self.repository.create(entrega)

    def listar_entregas(self, status: Optional[str] = None) -> List[Entrega]:
        if status is not None and status not in _STATUS_VALIDOS:
            raise StatusInvalido(f"Status inválido: '{status}'")
        return self.repository.list_all(status)

    def buscar_entrega(self, entrega_id: int) -> Entrega:
        entrega = self.repository.get_by_id(entrega_id)
        if entrega is None:
            raise EntregaNaoEncontrada(f"Entrega {entrega_id} não encontrada")
        return entrega

    def atualizar_status(self, entrega_id: int, novo_status: str) -> Entrega:
        if not isinstance(novo_status, str) or not novo_status.strip():
            raise StatusInvalido("Status não pode ser vazio")
        if novo_status not in _STATUS_VALIDOS:
            raise StatusInvalido(f"Status inválido: '{novo_status}'")

        entrega = self.repository.update_status(entrega_id, novo_status)
        if entrega is None:
            raise EntregaNaoEncontrada(f"Entrega {entrega_id} não encontrada")
        return entrega
