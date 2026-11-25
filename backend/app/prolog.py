"""Ponte entre Python e Prolog usando a biblioteca janus.

janus (pacote `janus-swi`) embute o SWI-Prolog dentro do processo Python.
Não há servidor Prolog separado nem troca de mensagens: chamamos predicados
diretamente e recebemos as respostas como dicionários Python.

Conversão automática de tipos (Python -> Prolog):
    int          -> inteiro
    str          -> string  (use janus.Term / átomos com cuidado, veja abaixo)
    list         -> lista
    dict         -> dict do SWI-Prolog

Para mais detalhes: https://www.swi-prolog.org/pldoc/man?section=janus

Este é o ÚNICO arquivo do projeto que conhece o janus. O resto do backend
só chama as funções abaixo.
"""

from pathlib import Path
from typing import Any

import janus_swi as janus

Grid = list[list[int]]
Cell = list[int]

Puzzle = dict[str, Any]

PROLOG_DIR = Path(__file__).parent.parent / "prolog"

# consult/1 carrega o arquivo .pl, como `?- [gerador].` no terminal do swipl.
# Os três carregam o rack.pl, onde estão as regras do jogo.
for name in ("gerador.pl", "dica.pl", "verificar.pl"):
    janus.consult(str(PROLOG_DIR / name))

# O janus converte dict do Python em dict do SWI-Prolog, e não no termo
# puzzle/5 que os predicados esperam. Por isso os campos vão como variáveis
# soltas e o termo é montado dentro da própria consulta. Variáveis que
# começam com _ não voltam no resultado de query_once.
PUZZLE_TERM = "_Puzzle = puzzle(Rows, Cols, RowCounts, ColCounts, Sensors)"

# Os níveis chegam em inglês pela API; o gerador usa os nomes em português.
LEVELS = {"easy": "facil", "medium": "medio", "hard": "dificil"}


class NoSolution(Exception):
    """O tabuleiro enviado não tem solução."""


class BoardComplete(Exception):
    """O tabuleiro não tem casas vazias: não há dica para dar."""


def _bindings(puzzle: Puzzle, marks: Grid) -> dict[str, Any]:
    """Valores das variáveis de PUZZLE_TERM e das marcas para a consulta."""
    return {
        "Rows": puzzle["rows"],
        "Cols": puzzle["cols"],
        "RowCounts": puzzle["rowCounts"],
        "ColCounts": puzzle["colCounts"],
        "Sensors": puzzle["sensors"],
        "Marks": marks,
    }


def generate(difficulty: str) -> Puzzle:
    # Strings do Python viram strings do Prolog, mas gerar/2 espera um
    # ÁTOMO (facil, medio, dificil). atom_string/2 faz a conversão do lado
    # Prolog, e o puzzle/5 da consulta desmonta o termo em campos.
    result = janus.query_once(
        "atom_string(Nivel, Name),"
        " gerador:gerar(Nivel, puzzle(Rows, Cols, RowCounts, ColCounts, Sensors))",
        {"Name": LEVELS[difficulty]},
    )
    return {
        "rows": result["Rows"],
        "cols": result["Cols"],
        "rowCounts": result["RowCounts"],
        "colCounts": result["ColCounts"],
        "sensors": result["Sensors"],
    }


def solve(puzzle: Puzzle, marks: Grid) -> Grid:
    # query_once executa a consulta e devolve um dict com as variáveis da
    # consulta (em maiúsculas, como no Prolog) e a chave 'truth', que diz se
    # a consulta teve sucesso.
    result = janus.query_once(
        f"{PUZZLE_TERM}, rack:resolver(_Puzzle, Marks, Grid)",
        _bindings(puzzle, marks),
    )
    if not result["truth"]:
        raise NoSolution
    return result["Grid"]


def hint(puzzle: Puzzle, marks: Grid) -> tuple[int, int, int, dict[str, Any]]:
    # O motivo é um termo composto (sensor(1, 2), combinado...). O =.. do
    # Prolog o desmonta em nome e argumentos, que chegam ao Python como
    # string e lista.
    result = janus.query_once(
        f"{PUZZLE_TERM}, dica:dica(_Puzzle, Marks, [Row, Col, Value, _Motivo]),"
        " _Motivo =.. [Kind | Args]",
        _bindings(puzzle, marks),
    )
    if not result["truth"]:
        # dica/3 falha em dois casos. Se as marcas não têm solução, solve
        # levanta NoSolution; se têm, é porque não sobrou casa aberta.
        solve(puzzle, marks)
        raise BoardComplete
    return result["Row"], result["Col"], result["Value"], _reason(
        result["Kind"], result["Args"]
    )


def _reason(kind: str, args: list[int]) -> dict[str, Any]:
    """Traduz o motivo de dica/3 para o formato `reason` do contrato."""
    # O `match` escolhe o ramo pela FORMA do valor, parecido com o casamento
    # de padrões do Prolog e do Elm.
    match kind, args:
        case "linha", [index]:
            return {"kind": "row", "index": index}
        case "coluna", [index]:
            return {"kind": "col", "index": index}
        case "sensor", [row, col]:
            return {"kind": "sensor", "row": row, "col": col}
        case "refrigeracao", [row, col]:
            return {"kind": "cooling", "row": row, "col": col}
        case "combinado", []:
            return {"kind": "combined"}
    raise ValueError(f"motivo inesperado de dica/3: {kind}{args}")


def check(puzzle: Puzzle, marks: Grid) -> list[Cell]:
    """Devolve as casas cuja marca contradiz a solução (vazia se nenhuma)."""
    result = janus.query_once(
        f"{PUZZLE_TERM}, verificar:verificar(_Puzzle, Marks, _Resultado),"
        " _Resultado =.. [Status | Args]",
        _bindings(puzzle, marks),
    )
    if not result["truth"]:
        raise NoSolution
    match result["Status"], result["Args"]:
        case "ok", []:
            return []
        case "contradicao", [cells]:
            return cells
    raise ValueError(f"resultado inesperado de verificar/3: {result!r}")
