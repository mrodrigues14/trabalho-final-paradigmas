"""API HTTP do Rack.

Esta camada é só "cola": recebe JSON, valida o formato com Pydantic, chama o
Prolog (via app/prolog.py) e devolve JSON. Nenhuma regra do jogo mora aqui.

Rodar em modo de desenvolvimento (recarrega ao salvar):
    uv run fastapi dev app/main.py

Documentação interativa gerada automaticamente: http://localhost:8000/docs
"""

from typing import Annotated, Literal

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, ConfigDict, Field, model_validator
from pydantic.alias_generators import to_camel

from app import prolog

app = FastAPI(title="Rack (Prolog + Elm)")

# O maior nível (difícil) é 10x10; acima disso o resolvedor fica lento.
MAX_SIZE = 10

# O Pydantic rejeita automaticamente (erro 422) qualquer valor fora destas
# faixas. As regras do jogo (cargas, sensores, refrigeração) ficam no Prolog.
Size = Annotated[int, Field(ge=1, le=MAX_SIZE)]
Index = Annotated[int, Field(ge=0)]
Count = Annotated[int, Field(ge=0)]
SensorNumber = Annotated[int, Field(ge=0, le=8)]
Mark = Annotated[int, Field(ge=0, le=2)]  # 0 sem marca, 1 servidor, 2 livre
Difficulty = Literal["easy", "medium", "hard"]


class CamelModel(BaseModel):
    """Campos em snake_case no Python e em camelCase no JSON (rowCounts)."""

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class Puzzle(CamelModel):
    rows: Size
    cols: Size
    row_counts: list[Count]
    col_counts: list[Count]
    sensors: list[tuple[Index, Index, SensorNumber]]  # [linha, coluna, número]

    @model_validator(mode="after")
    def fits_grid(self) -> "Puzzle":
        if len(self.row_counts) != self.rows or len(self.col_counts) != self.cols:
            raise ValueError("rowCounts e colCounts precisam ter rows e cols números.")
        if any(r >= self.rows or c >= self.cols for r, c, _ in self.sensors):
            raise ValueError("Todo sensor precisa estar dentro da grade.")
        return self


class GenerateRequest(BaseModel):
    difficulty: Difficulty = "medium"


class BoardRequest(BaseModel):
    puzzle: Puzzle
    marks: list[list[Mark]]

    @model_validator(mode="after")
    def marks_fit_puzzle(self) -> "BoardRequest":
        if len(self.marks) != self.puzzle.rows or any(
            len(row) != self.puzzle.cols for row in self.marks
        ):
            raise ValueError("marks precisa ser uma grade rows x cols.")
        return self

    def to_prolog(self) -> tuple[prolog.Puzzle, prolog.Grid]:
        # mode="json" entrega listas (e não tuplas, que o janus converteria
        # em outro termo) e by_alias mantém os nomes do contrato.
        return self.puzzle.model_dump(mode="json", by_alias=True), self.marks


class GenerateResponse(BaseModel):
    puzzle: Puzzle
    difficulty: Difficulty


class SolveResponse(BaseModel):
    grid: list[list[int]]


class Reason(BaseModel):
    kind: Literal["row", "col", "sensor", "cooling", "combined"]
    index: int | None = None
    row: int | None = None
    col: int | None = None


class HintResponse(BaseModel):
    row: int
    col: int
    value: int
    reason: Reason


class CheckResponse(BaseModel):
    status: Literal["ok", "contradiction"]
    cells: list[list[int]] | None = None


# Mensagens que o Elm mostra na tela quando a resposta é 422.
NO_SOLUTION = "As marcas atuais não levam a nenhuma solução. Confira as casas marcadas."
BOARD_COMPLETE = "O tabuleiro já está completo."


@app.post("/api/generate")
def generate(request: GenerateRequest) -> GenerateResponse:
    puzzle = Puzzle.model_validate(prolog.generate(request.difficulty))
    return GenerateResponse(puzzle=puzzle, difficulty=request.difficulty)


@app.post("/api/solve")
def solve(request: BoardRequest) -> SolveResponse:
    try:
        return SolveResponse(grid=prolog.solve(*request.to_prolog()))
    except prolog.NoSolution:
        # `from None` diz que a HTTPException SUBSTITUI a exceção original,
        # em vez de ser "causada" por ela; o traceback fica mais limpo.
        raise HTTPException(status_code=422, detail=NO_SOLUTION) from None


@app.post("/api/hint", response_model_exclude_none=True)
def hint(request: BoardRequest) -> HintResponse:
    try:
        row, col, value, reason = prolog.hint(*request.to_prolog())
    except prolog.NoSolution:
        raise HTTPException(status_code=422, detail=NO_SOLUTION) from None
    except prolog.BoardComplete:
        raise HTTPException(status_code=422, detail=BOARD_COMPLETE) from None
    return HintResponse(row=row, col=col, value=value, reason=Reason(**reason))


@app.post("/api/check", response_model_exclude_none=True)
def check(request: BoardRequest) -> CheckResponse:
    try:
        cells = prolog.check(*request.to_prolog())
    except prolog.NoSolution:
        raise HTTPException(status_code=422, detail=NO_SOLUTION) from None
    if cells:
        return CheckResponse(status="contradiction", cells=cells)
    return CheckResponse(status="ok")
