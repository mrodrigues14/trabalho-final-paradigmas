/*  gerador.pl: geração de puzzles do Rack.

    O gerador trabalha em etapas:

    1. solucao_aleatoria/3: sorteia uma grade COMPLETA de servidores que
       respeita a refrigeração (dois servidores nunca encostam pelos lados)
       e tem uma densidade razoável de servidores.

    2. derivar_pistas/2: a partir dessa grade, calcula as cargas de cada
       linha e coluna e põe um sensor em toda casa livre.

    3. enxugar/2: retira sensores em ordem aleatória, um por vez, e só
       aceita a retirada se o puzzle continuar com solução única.

    gerar/2 junta as três etapas com o tamanho de cada nível.

    As regras do jogo NÃO são reescritas aqui: elas vêm de rack_restricoes/2
    (rack.pl). O gerador só decide em que ordem e com que valores rotular.

    COMO TESTAR NO TERMINAL
    -----------------------
        $ swipl backend/prolog/gerador.pl
        ?- solucao_aleatoria(6, 6, G), maplist(writeln, G).
        ?- solucao_aleatoria(6, 6, G), derivar_pistas(G, P), rack:imprimir(P, G).
        ?- time(gerar(dificil, P)), once(rack:resolver(P, _, S)), rack:imprimir(P, S).
*/

:- module(gerador,
          [ solucao_aleatoria/3,     % +Linhas, +Colunas, -Grade
            derivar_pistas/2,        % +Grade, -Puzzle
            enxugar/2,               % +Puzzle0, -Puzzle
            enxugar/3,               % +Puzzle0, +Minimo, -Puzzle
            gerar/2,                 % +Nivel, -Puzzle
            tamanho/3                % ?Nivel, ?Linhas, ?Colunas
          ]).

:- use_module(library(clpfd)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(random)).
:- use_module(library(aggregate)).
:- use_module(rack).


/* =========================================================================
   1. SOLUÇÃO ALEATÓRIA
   ========================================================================= */

%!  chance_servidor(?P) is det.
%
%   Probabilidade de tentar primeiro o valor 1 (servidor) ao rotular uma
%   casa. Com 0,6, a densidade média fica perto de 30%.
chance_servidor(0.6).

%!  densidade(?Min, ?Max) is det.
%
%   Porcentagem mínima e máxima de servidores numa solução gerada.
densidade(25, 35).

%!  tentativas(?N) is det.
%
%   Quantas grades sortear antes de desistir. Só serve de proteção para
%   tamanhos em que a densidade é impossível (uma grade 1x1, por exemplo).
tentativas(1000).

%!  solucao_aleatoria(+L, +C, -Grade) is semidet.
%
%   Grade é uma grade L x C de 0 e 1 que respeita a refrigeração e tem
%   entre 25% e 35% de servidores.
%
%   É "gerar e testar": sorteia uma grade e confere a densidade. Se não
%   bater, between/3 dá a próxima tentativa. A densidade não entra como
%   restrição do CLP(FD) de propósito: uma grade que termina abaixo do
%   mínimo faria o labeling voltar atrás por dezenas de casas. Sorteando
%   de novo, cerca de 80% (6x6) a 97% (10x10) das grades já passam de
%   primeira.
solucao_aleatoria(L, C, Grade) :-
    tentativas(N),
    between(1, N, _),
    once(grade_aleatoria(L, C, Grade)),
    densidade_aceitavel(L, C, Grade),
    !.

%!  grade_aleatoria(+L, +C, -Grade) is nondet.
%
%   Reaproveita as regras do rack.pl com cargas livres e sem sensores:
%   sobra só a refrigeração restringindo de fato. As casas são rotuladas
%   em ordem aleatória, para os servidores se espalharem pela grade toda.
grade_aleatoria(L, C, Grade) :-
    rack_restricoes(puzzle(L, C, _CargasLinha, _CargasColuna, []), Grade),
    append(Grade, Casas),
    random_permutation(Casas, Ordem),
    rotular_aleatorio(Ordem).

%!  rotular_aleatorio(+Casas) is nondet.
%
%   Variante de label/1 que sorteia, para cada casa, se tenta 1 ou 0
%   primeiro. Se a propagação já fixou a casa (um vizinho é servidor),
%   member/2 só aceita o valor que sobrou.
rotular_aleatorio([]).
rotular_aleatorio([Casa | Casas]) :-
    ordem_dos_valores(Valores),
    member(Casa, Valores),
    rotular_aleatorio(Casas).

ordem_dos_valores(Valores) :-
    chance_servidor(P),
    (   maybe(P)
    ->  Valores = [1, 0]
    ;   Valores = [0, 1]
    ).

%!  densidade_aceitavel(+L, +C, +Grade) is semidet.
densidade_aceitavel(L, C, Grade) :-
    densidade(Min, Max),
    append(Grade, Casas),
    sum_list(Casas, Servidores),
    Servidores * 100 >= Min * L * C,
    Servidores * 100 =< Max * L * C.


/* =========================================================================
   2. PISTAS DERIVADAS DA SOLUÇÃO
   ========================================================================= */

%!  derivar_pistas(+Grade, -Puzzle) is det.
%
%   Puzzle tem as cargas de Grade e um sensor em TODA casa livre, com o
%   número de servidores nas 8 casas em volta.
%
%   Esse puzzle tem solução única por construção: as casas sem sensor são
%   exatamente os servidores, e as cargas obrigam todas elas a valer 1.
%   Depois, enxugar/2 retira sensores enquanto a solução continuar única.
derivar_pistas(Grade, puzzle(L, C, CargasLinha, CargasColuna, Sensores)) :-
    length(Grade, L),
    Grade = [PrimeiraLinha | _],
    length(PrimeiraLinha, C),
    maplist(sum_list, Grade, CargasLinha),
    transpose(Grade, Colunas),
    maplist(sum_list, Colunas, CargasColuna),
    findall([R, Col, N],
            ( nth0(R, Grade, Linha),
              nth0(Col, Linha, 0),
              servidores_em_volta(Grade, R, Col, N) ),
            Sensores).

%!  servidores_em_volta(+Grade, +R, +C, -N) is det.
servidores_em_volta(Grade, R, C, N) :-
    aggregate_all(count, casa_em_volta(Grade, R, C, 1), N).

%!  casa_em_volta(+Grade, +R, +C, ?X) is nondet.
%
%   X é o valor de uma das (até) 8 casas em volta de (R, C). Em vez de
%   somar deslocamentos e checar os limites da grade, enumeramos as casas
%   que existem e ficamos com as que estão a distância 1: os limites saem
%   de graça, porque nth0/3 só gera índices válidos.
casa_em_volta(Grade, R, C, X) :-
    nth0(R1, Grade, Linha),
    abs(R1 - R) =< 1,
    nth0(C1, Linha, X),
    abs(C1 - C) =< 1,
    R1-C1 \== R-C.


/* =========================================================================
   3. RETIRADA DE SENSORES
   ========================================================================= */

%!  enxugar(+Puzzle0, -Puzzle) is det.
%
%   Retira todos os sensores que conseguir, mantendo a solução única.
enxugar(Puzzle0, Puzzle) :-
    enxugar(Puzzle0, 0, Puzzle).

%!  enxugar(+Puzzle0, +Minimo, -Puzzle) is det.
%
%   Tenta retirar cada sensor, em ordem aleatória, sem deixar o puzzle com
%   menos de Minimo sensores. foldl/4 passa o puzzle de uma tentativa para
%   a próxima: cada passo devolve um puzzle NOVO, nada é alterado no lugar.
%
%   A ideia é a mesma do dig_holes/4 do sudoku.pl do modelo do professor.
enxugar(Puzzle0, Minimo, Puzzle) :-
    Puzzle0 = puzzle(_, _, _, _, Sensores),
    random_permutation(Sensores, Ordem),
    foldl(tentar_retirar(Minimo), Ordem, Puzzle0, Puzzle).

%!  tentar_retirar(+Minimo, +Sensor, +Puzzle0, -Puzzle) is det.
%
%   Puzzle é Puzzle0 sem Sensor, se o puzzle ainda tiver mais de Minimo
%   sensores e a solução continuar única. Senão, Puzzle é o próprio Puzzle0.
%   O "Se -> Então ; Senão" escolhe entre os dois sem deixar ponto de
%   escolha: tentar_retirar/4 sempre dá uma resposta só.
tentar_retirar(Minimo, Sensor, Puzzle0, Puzzle) :-
    Puzzle0 = puzzle(L, C, CargasLinha, CargasColuna, Sensores0),
    Candidato = puzzle(L, C, CargasLinha, CargasColuna, Sensores),
    (   length(Sensores0, N),
        N > Minimo,
        selectchk(Sensor, Sensores0, Sensores),
        unicidade_comprovada(Candidato)
    ->  Puzzle = Candidato
    ;   Puzzle = Puzzle0
    ).

%!  limite_inferencias(?N) is det.
%
%   Orçamento de cada checagem de unicidade, em inferências do Prolog.
limite_inferencias(500000).

%!  unicidade_comprovada(+Puzzle) is semidet.
%
%   Puzzle tem solução única E o resolvedor conseguiu provar isso dentro do
%   orçamento. contar_solucoes/3 com limite 2 basta: não importa se são 2
%   ou 2 mil soluções, só se é mais de uma. Em 10x10 com poucos sensores, provar que não existe uma
%   segunda solução pode levar dezenas de segundos. Quando o orçamento
%   estoura, a checagem falha e o sensor fica: o puzzle nunca perde a
%   unicidade, só termina com uma pista a mais. Contar inferências (e não
%   segundos) deixa o resultado igual em qualquer máquina.
unicidade_comprovada(Puzzle) :-
    limite_inferencias(Limite),
    call_with_inference_limit(contar_solucoes(Puzzle, 2, N), Limite, Resultado),
    Resultado \== inference_limit_exceeded,
    N =:= 1.


/* =========================================================================
   4. GERAR POR NÍVEL
   ========================================================================= */

%!  tamanho(?Nivel, ?Linhas, ?Colunas) is nondet.
tamanho(facil,   6,  6).
tamanho(medio,   8,  8).
tamanho(dificil, 10, 10).

%!  sensores_minimos(?Nivel, ?N) is nondet.
%
%   Quantos sensores o enxugar/3 deixa no mínimo. Proporcionalmente, o
%   fácil fica com mais pistas (10 em 36 casas) que o difícil (12 em 100).
%   No difícil o mínimo também segura o tempo: com menos de 12 sensores, a
%   checagem de unicidade quase sempre estoura o orçamento.
sensores_minimos(facil,   10).
sensores_minimos(medio,   10).
sensores_minimos(dificil, 12).

%!  gerar(+Nivel, -Puzzle) is det.
%
%   Puzzle é um puzzle novo, com solução única, no tamanho do Nivel.
gerar(Nivel, Puzzle) :-
    must_be(oneof([facil, medio, dificil]), Nivel),
    tamanho(Nivel, L, C),
    sensores_minimos(Nivel, Minimo),
    solucao_aleatoria(L, C, Grade),
    derivar_pistas(Grade, Puzzle0),
    enxugar(Puzzle0, Minimo, Puzzle).
