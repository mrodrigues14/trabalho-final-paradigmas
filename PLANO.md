# Plano de trabalho: equipe Funciona na Minha Máquina

Trabalho final de Paradigmas de Programação (Prolog + Elm), 5 integrantes.

**Entrega alvo: quarta, 25/11, 23h59 (Lote 2, sem desconto).**
Depois disso, **ninguém faz push**: um push depois de 25/11 joga o grupo
para o Lote 3, e G é multiplicado por 0,75.

---

## 0. Antes de tudo (hoje, 22/11)

| # | Tarefa | Quem |
|---|--------|------|
| 1 | Entrar na equipe no Codehood com o código **HZSWWJK4** (prazo: 25/11, 23h59) | os 4 colegas |
| 2 | Cada um copia a **própria** URL de clone na página do Codehood. Ela é pessoal e dá permissão de push: não mandar no grupo | todos |
| 3 | `git config user.name "Nome Completo"` e `git config user.email` com o e-mail de sempre (a distribuição de commits por autor é medida) | todos |
| 4 | Instalar SWI-Prolog 9.2+, uv e Node 20+; rodar `make install` e `make dev` e ver o Sudoku do modelo abrindo em http://localhost:5173 | todos |
| 5 | Ler o `AVALIACAO.md` inteiro e este plano | todos |
| 6 | Fazer o primeiro push com o modelo do professor, para todo mundo clonar a mesma base | Matheus |

**Ponto de partida:** o repositório já tem o modelo do professor (Sudoku).
Ele vira o esqueleto: mantemos a integração Python, o Vite e o CSS, e
trocamos o jogo inteiro.

**Lote 1 (23/11):** não vamos mirar nele. A página diz que vale o último
commit em cada data. Confirmar com o professor se um push parcial até 23/11
coloca o grupo para apresentar primeiro com o que estiver lá. Na dúvida,
o grupo combina não fazer push na segunda à noite.

---

## 1. O jogo: **Rack**

Um quebra-cabeça de lógica sobre montar um datacenter. Faixa declarada:
**remix original** (Δ = +0,5), que exige nível 3 ou mais em "funciona" e em
"Prolog". O professor confirma a faixa na apresentação.

### Regras

O tabuleiro é uma grade (6×6 fácil, 8×8 médio, 10×10 difícil). O jogador
decide, em cada casa aberta, se ali vai um **servidor** ou se fica **livre**.

1. **Carga por fileira.** O número ao lado de cada linha e acima de cada
   coluna diz quantos servidores ela tem.
2. **Sensores de calor.** Algumas casas têm um sensor com um número. A casa
   do sensor nunca tem servidor, e o número diz quantos servidores existem
   nas 8 casas em volta dele.
3. **Refrigeração.** Dois servidores nunca encostam pelos lados (na
   diagonal pode).
4. Todo puzzle gerado tem **uma única solução**.

Mecânicas conhecidas (contagem por linha e coluna, números de vizinhança do
Campo Minado, não adjacência) combinadas num jogo com regras próprias. Por
isso a faixa é remix, e não "jogo inventado".

### Por que Prolog serve aqui

- As regras viram restrições CLP(FD) sobre variáveis 0/1, quase uma por frase.
- **Geração** com busca: solução aleatória, depois retirada de pistas
  enquanto a solução continua única (contar soluções até 2).
- **Dica explicada:** o Prolog descobre uma casa forçada e diz **qual regra**
  a forçou ("o sensor em (2,3) já tem os 3 servidores que pede").
- **Dificuldade medida pelo raciocínio:** fácil se der para resolver só com
  dicas de uma regra, difícil se precisar combinar regras.

Esses quatro pontos cobrem o nível 4 do critério 2 (gerar, achar múltiplas
soluções, explicar o resultado e ter testes plunit).

> Se o grupo preferir outro jogo, a divisão de papéis, o cronograma e o
> fluxo de git abaixo continuam valendo. Só o conteúdo das seções 1, 3 e 4
> muda. A decisão tem que sair **hoje**.

---

## 2. Divisão de papéis

Cada pessoa é dona de arquivos próprios. Isso reduz conflito no git, deixa os
commits com autoria clara e garante que cada um saiba explicar o próprio
código na apresentação (perde até 1 ponto quem não souber, `AVALIACAO.md` 2.1).

| Pessoa | Papel | Arquivos | Peso na nota |
|--------|-------|----------|--------------|
| **A** | Prolog: regras e resolvedor | `backend/prolog/rack.pl`, `backend/prolog/test_rack.pl` | Prolog 20% |
| **B** | Prolog: gerador, dicas e dificuldade | `backend/prolog/gerador.pl`, `backend/prolog/dica.pl`, `backend/prolog/test_gerador.pl` | Prolog 20% |
| **C** | Elm: domínio, JSON e testes | `frontend/src/Rack.elm`, `frontend/src/Api.elm`, `frontend/tests/` | Elm 30% |
| **D** | Elm: interface | `frontend/src/Main.elm`, `frontend/src/View/*.elm`, `frontend/src/style.css` | Elm 30% |
| **E** | Integração, verificação, testes de API, relatório e apresentação | `backend/app/*.py`, `backend/tests/`, `backend/prolog/verificar.pl`, `RELATORIO.md`, `docs/` | Funciona 15%, Relatório 10%, Apresentação 15% |

A pessoa E também escreve um predicado Prolog (`verificar.pl`). Assim todo
mundo tem código de Prolog ou de Elm para explicar.

**Pares de revisão** (cada um lê e testa o código do par antes do push):
A ↔ B, C ↔ D, E revisa a integração de todos.

---

## 3. Contrato da API (fechar até segunda, 12h)

Este contrato é o que deixa os 5 trabalharem em paralelo: o Elm usa dados
fixos com este formato antes de o backend existir, e o Prolog é testado
sozinho no `swipl`.

### Formatos

```jsonc
// Puzzle
{
  "rows": 6, "cols": 6,
  "rowCounts": [2, 1, 2, 1, 2, 1],
  "colCounts": [1, 2, 1, 2, 1, 2],
  "sensors": [[0, 3, 2], [4, 1, 3]]      // [linha, coluna, número]
}

// Marcas do jogador: grade rows × cols
// 0 = sem marca, 1 = servidor, 2 = livre (casa de sensor sempre 0)
"marks": [[0, 1, 0, 2, 0, 0], ...]
```

### Rotas

| Rota | Corpo | Resposta 200 | Erro 422 | Predicado | Dono |
|------|-------|--------------|----------|-----------|------|
| `POST /api/generate` | `{"difficulty": "easy"}` | `{"puzzle": {...}, "difficulty": "easy"}` | não tem | `gerar/2` | B |
| `POST /api/solve` | `{"puzzle": {...}, "marks": [[...]]}` | `{"grid": [[0,1,...]]}` (1 = servidor) | sem solução a partir das marcas | `resolver/3` | A |
| `POST /api/hint` | `{"puzzle": {...}, "marks": [[...]]}` | `{"row": 2, "col": 3, "value": 1, "reason": {"kind": "sensor", "row": 1, "col": 2}}` | tabuleiro completo, ou marcas em contradição | `dica/3` | B |
| `POST /api/check` | `{"puzzle": {...}, "marks": [[...]]}` | `{"status": "ok"}` ou `{"status": "contradiction", "cells": [[r, c], ...]}` | não tem | `verificar/3` | E |

Valores de `reason.kind`: `"row"` (com `index`), `"col"` (com `index`),
`"sensor"` (com `row` e `col`), `"cooling"` (com `row` e `col` do servidor
vizinho), `"combined"` (precisou combinar regras).

O Python só valida o formato (Pydantic), chama o Prolog e converte listas
em JSON. Nenhuma regra mora no Python: acima de uns 30% de Python é sinal
de lógica no lugar errado.

---

## 4. O que cada pessoa implementa

### Pessoa A: regras e resolvedor (`rack.pl`)

**Entregáveis**

- `rack_restricoes(+Puzzle, -Grade)`: monta a grade de variáveis 0..1 e
  posta as 3 regras.
- `aplicar_marcas(+Grade, +Marcas)`: marca 1 vira `X = 1`, marca 2 vira
  `X = 0`, marca 0 deixa a variável livre.
- `resolver(+Puzzle, +Marcas, -Solucao)`: restrições, marcas e `label/1`.
- `contar_solucoes(+Puzzle, +Limite, -N)`: para checar unicidade com
  `findall/3` mais `limit/2`.
- `puzzle_exemplo/1` e `imprimir/2` para testar no terminal.
- Testes plunit: puzzle de exemplo com solução conhecida, puzzle sem solução,
  sensor com 0, sensor no canto (só 3 vizinhos), linha com carga 0,
  unicidade dos exemplos.

**Esqueleto**

```prolog
:- module(rack, [rack_restricoes/2, resolver/3, contar_solucoes/3]).
:- use_module(library(clpfd)).

% Puzzle = puzzle(Linhas, Colunas, CargasLinha, CargasColuna, Sensores)
rack_restricoes(puzzle(L, C, CL, CC, Sensores), Grade) :-
    length(Grade, L),
    maplist(tamanho(C), Grade),
    append(Grade, Casas),
    Casas ins 0..1,
    maplist(soma_igual, Grade, CL),                 % regra 1, linhas
    transpose(Grade, Colunas),
    maplist(soma_igual, Colunas, CC),               % regra 1, colunas
    maplist(sensor(Grade), Sensores),               % regra 2
    refrigeracao(Grade, Colunas).                   % regra 3

soma_igual(Fileira, N) :- sum(Fileira, #=, N).

sensor(Grade, [R, C, N]) :-
    casa(Grade, R, C, X), X #= 0,
    vizinhos8(Grade, R, C, Vs),
    sum(Vs, #=, N).

refrigeracao(Linhas, Colunas) :-
    maplist(sem_encostar, Linhas),
    maplist(sem_encostar, Colunas).

sem_encostar([]).
sem_encostar([_]).
sem_encostar([A, B | T]) :- A + B #=< 1, sem_encostar([B | T]).
```

Usar `nth0/3` e `findall/3` em `vizinhos8/4`, com os limites da grade como
condição (sem `if` imperativo).

**Pronto quando:** `swipl -g run_tests -t halt backend/prolog/test_rack.pl`
passa e `swipl backend/prolog/rack.pl` carrega **sem avisos**.

### Pessoa B: gerador, dicas e dificuldade (`gerador.pl`, `dica.pl`)

**Entregáveis**

- `solucao_aleatoria(+L, +C, -Grade)`: só a regra 3 mais uma densidade
  (entre 25% e 35% de servidores), com rotulagem em ordem aleatória. O
  `random_labeling/1` do `sudoku.pl` do modelo serve de referência
  (declarar na seção 11).
- `derivar_pistas(+Grade, -Puzzle)`: calcula as cargas e coloca sensores
  em casas livres sorteadas.
- `enxugar(+Puzzle0, -Puzzle)`: tira sensores um a um, mantendo cada
  retirada só se `contar_solucoes(P, 2, 1)` continuar valendo.
- `gerar(+Dificuldade, -Puzzle)`: tamanho por nível, como fato
  (`tamanho(facil, 6, 6).`).
- `dica(+Puzzle, +Marcas, -Dica)`, com a ideia central do projeto:

```prolog
% Uma casa está forçada se o valor oposto torna UMA regra impossível,
% só com propagação, sem rotular nada.
dica(Puzzle, Marcas, [R, C, V, Motivo]) :-
    casa_aberta(Puzzle, Marcas, R, C),
    member(V, [1, 0]),
    Oposto is 1 - V,
    regra(Puzzle, Regra),
    \+ consistente(Puzzle, Marcas, Regra, R, C, Oposto),
    motivo(Regra, Motivo),
    !.
```

  `regra/2` enumera cada linha, cada coluna, cada sensor e cada par de
  vizinhas por backtracking, e `consistente/5` posta **só aquela regra**.
  Se nenhuma regra sozinha decidir, cai no caso `combined` (todas as
  restrições juntas). `\+` e `!` precisam ser justificados na seção 5.2.
- `dificuldade(+Puzzle, -Nivel)`: resolve aplicando dicas em sequência;
  se nunca precisou de `combined`, é fácil.
- Testes plunit: o puzzle gerado tem solução única, a dica bate com a
  solução, o motivo devolvido é coerente, tabuleiro completo não tem dica.

**Pronto quando:** `gerar(dificil, P)` roda em menos de 3 segundos e todos
os testes passam.

### Pessoa C: domínio Elm, JSON e testes (`Rack.elm`, `Api.elm`)

`Rack.elm` é **puro**: não importa `Html` nem `Http`.

```elm
type alias Posicao = { linha : Int, coluna : Int }

type Marca = SemMarca | Servidor | Livre

type Casa
    = Sensor Int
    | Aberta Marca

type alias Puzzle =
    { linhas : Int
    , colunas : Int
    , cargasLinha : Array Int
    , cargasColuna : Array Int
    , casas : Array (Array Casa)
    }

type Conflito
    = LinhaExcedida Int
    | ColunaExcedida Int
    | SensorExcedido Posicao
    | ServidoresEncostados Posicao Posicao

type Motivo
    = PorLinha Int
    | PorColuna Int
    | PorSensor Posicao
    | PorRefrigeracao Posicao
    | Combinado

type alias Dica = { posicao : Posicao, valor : Marca, motivo : Motivo }

type Dificuldade = Facil | Medio | Dificil
```

Um sensor é `Sensor Int` e não uma casa com `Bool` "tem sensor": assim o
jogador não consegue marcar servidor em cima de sensor. Esse argumento vai
na seção 6.1.

**Funções**

- `alternar : Posicao -> Puzzle -> Puzzle` (ciclo SemMarca → Servidor → Livre)
- `conflitos : Puzzle -> List Conflito` (validação instantânea, sem servidor)
- `venceu : Puzzle -> Bool` (cargas e sensores batem e não há conflito)
- `descreverMotivo : Motivo -> String` (texto da dica para a tela)
- `Api.elm`: decoders de `Puzzle`, `Dica` e do resultado da verificação,
  encoder das marcas e as 4 requisições. Erro HTTP vira `Result` com a
  mensagem do 422 (`detail`).
- **elm-test** (`npx elm-test init`): conflitos de linha, de sensor e de
  vizinhança, vitória, ciclo de marcas, decoder com JSON de exemplo.

**Pronto quando:** `elm make` compila sem aviso, `elm-format` aplicado e
`npx elm-test` passa.

### Pessoa D: interface (`Main.elm`, `View/`)

```elm
type Estado
    = Carregando Dificuldade
    | Jogando Jogo
    | Vitoria Jogo Int        -- segundos
    | Falha String

type alias Jogo =
    { puzzle : Puzzle
    , selecionada : Maybe Posicao
    , dica : Maybe Dica
    , segundos : Int
    , historico : List Puzzle  -- para desfazer
    }

type Msg
    = NovoJogo Dificuldade
    | PuzzleChegou (Result Http.Error Puzzle)
    | Clicou Posicao
    | Tecla Teclado
    | PediuDica
    | DicaChegou (Result String Dica)
    | PediuSolucao
    | SolucaoChegou (Result String (List (List Int)))
    | Desfazer
    | Tique
```

**Funcionalidades**

- Grade com cargas nas bordas; a carga fica verde quando bate e vermelha
  quando passa.
- Clique alterna a marca; teclado com setas, `S` servidor, `L` livre,
  `Backspace` limpa, `H` dica, `U` desfaz.
- Conflitos de `Rack.conflitos` destacados na hora.
- Painel da dica: destaca a casa e a regra responsável, com o texto de
  `descreverMotivo`.
- Seletor de dificuldade, cronômetro (`Time.every`), tela de vitória com
  o tempo, botão "mostrar solução".
- Tela de carregamento e de erro (com a mensagem que veio do backend).
- Adaptar o `style.css` do modelo (temas claro e escuro já prontos).
- Até segunda à noite, trabalhar com um puzzle fixo em JSON, sem backend.

**Pronto quando:** dá para jogar uma partida inteira só com o teclado, e
`elm make` compila sem aviso.

### Pessoa E: integração, verificação, testes e entrega

- `backend/app/prolog.py`: `janus.consult` do `rack.pl` (que carrega os
  outros módulos) e uma função por predicado. Strings viram átomos com
  `atom_string/2`, como no modelo.
- `backend/app/main.py`: as 4 rotas do contrato, com Pydantic validando
  tamanho da grade e valores das marcas.
- `backend/prolog/verificar.pl`: `verificar(+Puzzle, +Marcas, -Resultado)`
  devolve `ok` ou as casas marcadas que tornam o puzzle impossível
  (retirar uma marca por vez e ver quais derrubam a contradição).
- `backend/tests/test_api.py`: cada rota, os 422, marcas inválidas.
- `Makefile`: `test` rodando os três conjuntos (plunit, pytest, elm-test).
- Apagar o Sudoku (`sudoku.pl`, `test_sudoku.pl`, `Sudoku.elm`) quando o
  Rack estiver jogável. Código morto pesa no critério de qualidade.
- Editora do `RELATORIO.md` (seção 6 deste plano), capturas em
  `docs/captura.png`, slides opcionais em `docs/apresentacao.pdf`.
- Roda `make validar` antes de cada push combinado e faz o **teste em
  máquina limpa** da seção 3 do relatório (pedir para alguém de outro
  grupo, ou num usuário novo do sistema).

---

## 5. Cronograma

| Quando | A (Prolog regras) | B (Prolog gerador e dica) | C (Elm domínio) | D (Elm interface) | E (integração e relatório) |
|--------|-------------------|---------------------------|-----------------|-------------------|----------------------------|
| **Dom 22/11, noite** | setup | setup | setup | setup | setup, primeiro push do modelo |
| **Seg 23/11, até 12h** | contrato da API fechado (todos, 30 min de chamada) | | | | |
| **Seg 23/11** | regras 1 a 3, `resolver/3`, testes | `solucao_aleatoria/3`, `derivar_pistas/2` com o `rack.pl` em andamento | tipos, `alternar`, `conflitos`, decoders | grade com puzzle fixo, clique, cargas | rotas com resposta fixa (mock), testes de API |
| **Ter 24/11, manhã** | `contar_solucoes/3`, casos de borda | `enxugar/2`, `gerar/2` | `venceu`, elm-test | teclado, conflitos na tela, Api ligada | `prolog.py` real, `verificar.pl` |
| **Ter 24/11, tarde** | revisar código de B | `dica/3` com motivo | `descreverMotivo`, decoder da dica | painel da dica, cronômetro, vitória | integração ponta a ponta, apagar Sudoku |
| **Ter 24/11, noite** | **jogo completo rodando com `make dev`** (todos testam) | | | | |
| **Qua 25/11, até 18h** | seção 5 do relatório | `dificuldade/2` (se der tempo), seção 5.3 | seções 6.1 e 6.2 | seção 6.3, captura de tela | seções 2, 3, 4, 7, 8, 9 e 11 |
| **Qua 25/11, 18h** | **congelamento do código**: daqui em diante só correção de bug e relatório | | | | |
| **Qua 25/11, até 22h** | todos: seção 10 e 13 revisadas, `make test` e `make validar` sem erro | | | | |
| **Qua 25/11, até 23h** | E faz o último push e confere no Codehood que o commit chegou | | | | |

O que é opcional e cai primeiro se atrasar: `dificuldade/2` (o nível fica
só pelo tamanho da grade), desfazer e cronômetro.

O que **não pode cair**: as 3 regras, gerador com solução única, dica com
motivo, validação instantânea no Elm, testes plunit e elm-test, relatório.

---

## 6. Relatório (`RELATORIO.md`): quem escreve o quê

O validador confere a forma: nada entre colchetes, nenhum comentário de
instrução sobrando, tabelas bem formadas, arquivos citados existindo.
Sempre citar `arquivo:linha` em vez de descrever o código.

| Seção | Responsável | Observação |
|-------|-------------|------------|
| 1. Identificação | E (cada um manda nome, matrícula, turma, usuário) | Nome do grupo: Funciona na Minha Máquina. Repositório: o do Codehood. Ponto de partida: **remix original** |
| 2. Resumo | E | 3 a 5 linhas mais a captura |
| 3. Como executar | E | Testado em máquina limpa, com as versões usadas |
| 4. Arquitetura | E | Diagrama e tabela |
| 5.1 e 5.2 | A | Predicados com aridade e `arquivo:linha` |
| 5.3 Trecho em destaque | B | `dica/3`: por que é lógico e não imperativo |
| 6.1 Modelo e mensagens | C | Por que custom types e não `Bool` |
| 6.2 Conceitos | C | |
| 6.3 Trecho em destaque | D | `update` ou `conflitos` |
| 7. Integração | E | Tabela de rotas |
| 8. Testes | E, com A, B e C | Quantos testes, quais casos de borda |
| 9. Limitações | todos | Honestidade conta ponto |
| 10. Contribuição | todos concordam | Tem que bater com os commits |
| 11. Fontes e IA | E, revisado por todos | Declarar o modelo do professor e qualquer uso de IA |
| 12. Apresentação | E | Roteiro abaixo |
| 13. Reflexão | todos (1 parágrafo cada, E junta) | Exemplos do próprio código |

### Uso de IA (seção 11)

- Declarar **tudo**. Não declarar zera o trabalho; declarar não tira ponto.
- Faixa esperada: **auxiliar** (trechos gerados e revisados pelo grupo).
- Se a IA escrever a maior parte do código, a faixa vira **intensivo** e o
  Δ cai 0,5 (o remix passa a valer 0). Por isso cada um escreve o próprio
  código e usa IA para tirar dúvida e revisar.
- Cada um precisa entender cada linha que assina: é isso que o professor
  testa na apresentação.

---

## 7. Apresentação (15 minutos, todos falam)

| Parte | Duração | Quem |
|-------|:-------:|------|
| Contexto, regras do Rack e arquitetura | 2 min | E |
| Demonstração: partida fácil, dica explicada, conflito, vitória | 4 min | D |
| Prolog: as regras como restrições | 3 min | A |
| Prolog: gerador com unicidade e dica explicada | 3 min | B |
| Elm: tipos que impedem estados inválidos | 2 min | C |
| Limitações e aprendizados | 1 min | E |

Ensaiar uma vez com cronômetro, na quarta à noite ou depois da entrega.
Cada um prepara a explicação de um trecho do código de outra pessoa, porque
o professor pode perguntar qualquer coisa.

---

## 8. Git

O Codehood só aceita a branch `main` e não aceita force-push. Então:

```sh
# uma vez
git clone <sua-url-do-codehood> trabalho-final
cd trabalho-final
make install

# a cada tarefa
git pull --rebase
# ...edita só os seus arquivos...
make test
git add <seus arquivos>
git commit -m "Rack: sensores no resolvedor"
git pull --rebase
git push
```

Regras do grupo:

- Commits pequenos e frequentes, cada um com o próprio nome. Commit em nome
  de outra pessoa estraga a seção 10 e a avaliação 360.
- Não fazer push de código que quebra `make test`.
- Mexer em arquivo de outra pessoa só combinando antes (o contrato da API é
  a exceção: muda só com aviso no grupo).
- Nunca colocar a URL de clone em arquivo do repositório nem no grupo.
- **Nenhum push depois de quarta, 25/11, 23h59.**

---

## 9. Riscos

| Risco | O que fazer |
|-------|-------------|
| `janus-swi` não instala em alguém | Ver "Problemas comuns" no `README.md`; enquanto isso, a pessoa trabalha no `swipl` puro |
| Gerador de 10×10 lento | Diminuir o difícil para 8×8 com menos sensores; o nível ainda vem de `dificuldade/2` |
| Integração atrasa | D usa o puzzle fixo em JSON até terça à tarde; A e B testam só no `swipl` |
| Alguém some | Os pares de revisão conhecem o código do par e assumem |
| Relatório no último minuto | Cada seção tem dono e prazo (quarta, 18h); E cobra |

---

## 10. Checklist final (quarta, 22h)

- [ ] `make test` passa (plunit, pytest, elm-test)
- [ ] `swipl` carrega os `.pl` sem avisos; `elm make` sem avisos
- [ ] `elm-format` aplicado em todos os `.elm`
- [ ] `make validar` sem erros
- [ ] Sudoku do modelo removido
- [ ] Seção 3 do relatório testada em máquina limpa
- [ ] Seções 10 e 11 aprovadas pelos 5
- [ ] `arquivo:linha` do relatório conferidos com o commit final
- [ ] Commit da seção 1 é o último da `main` no Codehood
- [ ] Os 5 entraram na equipe no Codehood
- [ ] Cada um sabe que a avaliação 360 é uma atividade separada no Codehood
