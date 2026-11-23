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

sensores(puzzle(_, _, _, _, Sensores), Sensores).

:- begin_tests(enxugar).

test(retira_sensor_desnecessario, true(P == puzzle(1, 3, [2], [1, 0, 1], []))) :-
    enxugar(puzzle(1, 3, [2], [1, 0, 1], [[0, 1, 2]]), P).

test(mantem_sensor_necessario, true(P == P0)) :-
    P0 = puzzle(2, 2, [1, 1], [1, 1], [[0, 0, 2]]),
    enxugar(P0, P).

test(solucao_continua_unica, [forall(member(L-C, [6-6, 8-8, 4-7]))]) :-
    solucao_aleatoria(L, C, G),
    derivar_pistas(G, P0),
    enxugar(P0, P),
    contar_solucoes(P, 2, 1).

test(resolver_devolve_a_grade, [forall(member(L-C, [6-6, 8-8, 4-7]))]) :-
    solucao_aleatoria(L, C, G),
    derivar_pistas(G, P0),
    enxugar(P0, P),
    marcas_vazias(L, C, M),
    once(resolver(P, M, S)),
    S == G.

test(so_retira_sensores, [forall(member(L-C, [6-6, 8-8]))]) :-
    solucao_aleatoria(L, C, G),
    derivar_pistas(G, P0),
    enxugar(P0, P),
    P0 = puzzle(L, C, CargasLinha, CargasColuna, Sensores0),
    P = puzzle(L, C, CargasLinha, CargasColuna, Sensores),
    forall(member(S, Sensores), memberchk(S, Sensores0)),
    length(Sensores0, N0),
    length(Sensores, N),
    N < N0.

test(respeita_o_minimo) :-
    solucao_aleatoria(6, 6, G),
    derivar_pistas(G, P0),
    enxugar(P0, 15, P),
    sensores(P, Sensores),
    length(Sensores, N),
    N >= 15.

:- end_tests(enxugar).

:- begin_tests(gerar).

test(tamanho_do_nivel, [forall(tamanho(Nivel, L, C))]) :-
    gerar(Nivel, puzzle(L, C, CargasLinha, CargasColuna, _)),
    length(CargasLinha, L),
    length(CargasColuna, C).

test(solucao_unica, [forall(member(Nivel, [facil, medio, dificil]))]) :-
    gerar(Nivel, P),
    contar_solucoes(P, 2, 1).

test(sorteia_puzzles_diferentes, true(P1 \== P2)) :-
    gerar(facil, P1),
    gerar(facil, P2).

% O alvo do plano é 3 s; o limite de 5 s deixa folga para máquinas lentas.
test(dificil_rapido) :-
    call_with_time_limit(5, gerar(dificil, _)).

% must_be/2 lança type_error ou domain_error, conforme a versão do SWI;
% nos dois casos o segundo argumento é o valor recusado.
test(nivel_invalido, true(Recusado == easy)) :-
    catch(gerar(easy, _), error(Erro, _), arg(2, Erro, Recusado)).

:- end_tests(gerar).
