/*  gerador.pl: geração de puzzles do Rack.

    O gerador trabalha em etapas:

    1. solucao_aleatoria/3: sorteia uma grade COMPLETA de servidores que
       respeita a refrigeração (dois servidores nunca encostam pelos lados)
       e tem uma densidade razoável de servidores.

    As regras do jogo NÃO são reescritas aqui: elas vêm de rack_restricoes/2
    (rack.pl). O gerador só decide em que ordem e com que valores rotular.

    COMO TESTAR NO TERMINAL
    -----------------------
        $ swipl backend/prolog/gerador.pl
        ?- solucao_aleatoria(6, 6, G), maplist(writeln, G).
*/

:- module(gerador,
          [ solucao_aleatoria/3      % +Linhas, +Colunas, -Grade
          ]).

:- use_module(library(clpfd)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(random)).
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
