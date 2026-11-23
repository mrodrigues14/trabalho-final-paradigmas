:- use_module(gerador).
:- use_module(rack).
:- use_module(library(plunit)).
:- use_module(library(clpfd)).

% Cargas de linha e de coluna de uma grade completa.
cargas(Grade, CargasLinha, CargasColuna) :-
    maplist(sum_list, Grade, CargasLinha),
    transpose(Grade, Colunas),
    maplist(sum_list, Colunas, CargasColuna).

% A grade completa respeita as regras do rack.pl com as próprias cargas.
respeita_regras(Grade) :-
    length(Grade, L),
    Grade = [Linha | _],
    length(Linha, C),
    cargas(Grade, CargasLinha, CargasColuna),
    once(rack_restricoes(puzzle(L, C, CargasLinha, CargasColuna, []), Grade)).

porcentagem_servidores(Grade, P) :-
    append(Grade, Casas),
    length(Casas, Total),
    sum_list(Casas, Servidores),
    P is Servidores * 100 / Total.

tamanho_teste(6, 6).
tamanho_teste(8, 8).
tamanho_teste(10, 10).
tamanho_teste(4, 7).

:- begin_tests(solucao_aleatoria).

test(dimensoes, [forall(tamanho_teste(L, C))]) :-
    solucao_aleatoria(L, C, G),
    length(G, L),
    forall(member(Linha, G), length(Linha, C)).

test(so_zeros_e_uns, [forall(tamanho_teste(L, C))]) :-
    solucao_aleatoria(L, C, G),
    append(G, Casas),
    forall(member(X, Casas), memberchk(X, [0, 1])).

test(sem_servidores_encostados, [forall(tamanho_teste(L, C))]) :-
    solucao_aleatoria(L, C, G),
    respeita_regras(G).

test(densidade, [forall(tamanho_teste(L, C))]) :-
    solucao_aleatoria(L, C, G),
    porcentagem_servidores(G, P),
    P >= 25,
    P =< 35.

test(sorteia_grades_diferentes, true(G1 \== G2)) :-
    solucao_aleatoria(10, 10, G1),
    solucao_aleatoria(10, 10, G2).

test(densidade_impossivel, fail) :-
    solucao_aleatoria(1, 1, _).

:- end_tests(solucao_aleatoria).
