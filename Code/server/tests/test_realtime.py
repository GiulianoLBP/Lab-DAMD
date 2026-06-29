"""
Testes do hub de tempo real (fan-out em memória).

O ``RealtimeHub`` é a parte testável sem broker da notificação em tempo real:
a ponte RabbitMQ apenas chama ``publish()``; aqui validamos o fan-out, a
remoção de assinantes e o descarte sob fila cheia (cliente lento).
"""

import queue
import unittest

from app.realtime.hub import RealtimeHub


class RealtimeHubTests(unittest.TestCase):

    def test_publish_entrega_evento_a_todos_assinantes(self):
        hub = RealtimeHub()
        a = hub.subscribe()
        b = hub.subscribe()

        evento = {'evento': 'entrega.criada', 'dados': {'id': 1}}
        hub.publish(evento)

        self.assertEqual(evento, a.get_nowait())
        self.assertEqual(evento, b.get_nowait())
        self.assertEqual(2, hub.total)

    def test_unsubscribe_para_de_receber(self):
        hub = RealtimeHub()
        a = hub.subscribe()
        hub.unsubscribe(a)

        hub.publish({'evento': 'entrega.criada'})

        self.assertEqual(0, hub.total)
        with self.assertRaises(queue.Empty):
            a.get_nowait()

    def test_fila_cheia_descarta_sem_levantar_e_recupera(self):
        # Fila cheia (cliente lento) descarta o excedente SEM travar/estourar o
        # publish; após drenar, a entrega volta ao normal.
        hub = RealtimeHub(max_fila=1)
        fila = hub.subscribe()

        hub.publish({'n': 1})  # ocupa a única vaga
        hub.publish({'n': 2})  # descartado (fila cheia), mas não pode levantar

        self.assertEqual({'n': 1}, fila.get_nowait())
        self.assertTrue(fila.empty())  # n=2 foi descartado

        hub.publish({'n': 3})  # com a fila drenada, volta a receber
        self.assertEqual({'n': 3}, fila.get_nowait())


if __name__ == '__main__':
    unittest.main()
