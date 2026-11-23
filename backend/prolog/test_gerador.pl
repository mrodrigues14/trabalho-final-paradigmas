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

marcas_vazias(L, C, Marcas) :-
    length(Marcas, L),
    maplist(linha_vazia(C), Marcas).

linha_vazia(C, Linha) :-
    length(Linha, C),
    maplist(=(0), Linha).

:- begin_tests(derivar_pistas).

test(grade_pequena, true(P == puzzle(2, 2, [1, 0], [1, 0],
                                     [[0, 1, 1], [1, 0, 1], [1, 1, 1]]))) :-
    derivar_pistas([[1, 0],
                    [0, 0]], P).

test(sensor_no_meio_e_nos_cantos,
     true(Sensores == [[0, 0, 2], [0, 2, 2], [1, 1, 4], [2, 0, 2], [2, 2, 2]])) :-
    derivar_pistas([[0, 1, 0],
                    [1, 0, 1],
                    [0, 1, 0]], puzzle(3, 3, [1, 2, 1], [1, 2, 1], Sensores)).

test(cargas_batem_com_a_grade, [forall(tamanho_teste(L, C))]) :-
    solucao_aleatoria(L, C, G),
    derivar_pistas(G, puzzle(L, C, CargasLinha, CargasColuna, _)),
    cargas(G, CargasLinha, CargasColuna).

test(sensor_em_toda_casa_livre, [forall(tamanho_teste(L, C))]) :-
    solucao_aleatoria(L, C, G),
    derivar_pistas(G, puzzle(_, _, _, _, Sensores)),
    findall(R-Col, (nth0(R, G, Linha), nth0(Col, Linha, 0)), Livres),
    findall(R-Col, member([R, Col, _], Sensores), ComSensor),
    ComSensor == Livres.

test(solucao_unica, [forall(tamanho_teste(L, C))]) :-
    solucao_aleatoria(L, C, G),
    derivar_pistas(G, P),
    contar_solucoes(P, 2, 1).

test(resolver_devolve_a_grade, [forall(tamanho_teste(L, C))]) :-
    solucao_aleatoria(L, C, G),
    derivar_pistas(G, P),
    marcas_vazias(L, C, M),
    once(resolver(P, M, S)),
    S == G.

:- end_tests(derivar_pistas).
