"""Testes da API HTTP (pytest).

Usamos o TestClient do FastAPI: ele chama a aplicação diretamente, sem subir
um servidor nem abrir porta. Cada função `test_*` é um teste; o pytest as
encontra sozinho.

Rodar: `uv run pytest` (na pasta backend) ou `make test-backend` (na raiz).

As regras do Rack são testadas em Prolog (prolog/test_*.pl). Aqui
conferimos só a "cola": rotas, formato do JSON e códigos de status.
"""

import pytest
from fastapi.testclient import TestClient

from app.main import BOARD_COMPLETE, NO_SOLUTION, app

client = TestClient(app)

# O mesmo puzzle de puzzle_exemplo/1 em rack.pl.
EXAMPLE = {
    "rows": 6,
    "cols": 6,
    "rowCounts": [2, 2, 2, 1, 2, 2],
    "colCounts": [3, 1, 2, 2, 1, 2],
    "sensors": [[1, 4, 3], [2, 1, 3], [3, 0, 2], [3, 2, 2], [4, 2, 3]],
}

# A solução de solucao_exemplo/1 em test_rack.pl (1 = servidor).
SOLUTION = [
    [1, 0, 0, 1, 0, 0],
    [0, 0, 1, 0, 0, 1],
    [1, 0, 0, 0, 1, 0],
    [0, 1, 0, 0, 0, 0],
    [0, 0, 0, 1, 0, 1],
    [1, 0, 1, 0, 0, 0],
]


def empty_marks() -> list[list[int]]:
    return [[0] * 6 for _ in range(6)]


def wrong_marks() -> list[list[int]]:
    """Livre onde a solução tem servidor e servidor onde ela tem livre."""
    marks = empty_marks()
    marks[0][0] = 2
    marks[0][1] = 1
    return marks


def complete_marks() -> list[list[int]]:
    """A solução inteira como marcas (1 servidor, 2 livre; sensor fica 0)."""
    marks = [[1 if cell else 2 for cell in row] for row in SOLUTION]
    for row, col, _ in EXAMPLE["sensors"]:
        marks[row][col] = 0
    return marks


def post(route: str, marks: list[list[int]], puzzle: dict = EXAMPLE):
    return client.post(route, json={"puzzle": puzzle, "marks": marks})


@pytest.mark.parametrize("difficulty, size", [("easy", 6), ("medium", 8), ("hard", 10)])
def test_generate(difficulty, size):
    response = client.post("/api/generate", json={"difficulty": difficulty})
    assert response.status_code == 200
    body = response.json()
    assert body["difficulty"] == difficulty
    puzzle = body["puzzle"]
    assert puzzle["rows"] == puzzle["cols"] == size
    assert len(puzzle["rowCounts"]) == len(puzzle["colCounts"]) == size
    assert all(len(sensor) == 3 for sensor in puzzle["sensors"])


def test_generate_rejects_unknown_difficulty():
    response = client.post("/api/generate", json={"difficulty": "impossible"})
    assert response.status_code == 422


def test_solve():
    response = post("/api/solve", empty_marks())
    assert response.status_code == 200
    assert response.json() == {"grid": SOLUTION}


def test_solve_without_solution():
    response = post("/api/solve", wrong_marks())
    assert response.status_code == 422
    assert response.json()["detail"] == NO_SOLUTION


def test_hint():
    response = post("/api/hint", empty_marks())
    assert response.status_code == 200
    hint = response.json()
    assert hint["value"] == SOLUTION[hint["row"]][hint["col"]]  # bate com a solução
    assert hint["reason"]["kind"] in {"row", "col", "sensor", "cooling", "combined"}


def test_hint_reason_has_only_its_fields():
    # Com um servidor em (0, 0), a casa ao lado só pode ficar livre: o motivo
    # é a refrigeração, e o JSON não leva o `index`, que é de outro motivo.
    marks = empty_marks()
    marks[0][0] = 1
    response = post("/api/hint", marks)
    assert response.json() == {
        "row": 0,
        "col": 1,
        "value": 0,
        "reason": {"kind": "cooling", "row": 0, "col": 0},
    }


def test_hint_on_complete_board():
    response = post("/api/hint", complete_marks())
    assert response.status_code == 422
    assert response.json()["detail"] == BOARD_COMPLETE


def test_hint_with_contradiction():
    response = post("/api/hint", wrong_marks())
    assert response.status_code == 422
    assert response.json()["detail"] == NO_SOLUTION


def test_check_ok():
    response = post("/api/check", complete_marks())
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_check_contradiction():
    response = post("/api/check", wrong_marks())
    assert response.status_code == 200
    assert response.json() == {"status": "contradiction", "cells": [[0, 0], [0, 1]]}


# Quem rejeita os casos abaixo é o Pydantic, antes de o Prolog ser chamado.


def test_rejects_mark_out_of_range():
    marks = empty_marks()
    marks[0][0] = 3
    assert post("/api/check", marks).status_code == 422


def test_rejects_marks_of_wrong_size():
    assert post("/api/check", empty_marks()[:5]).status_code == 422


def test_rejects_sensor_outside_grid():
    puzzle = {**EXAMPLE, "sensors": [[6, 0, 1]]}
    assert post("/api/check", empty_marks(), puzzle).status_code == 422
