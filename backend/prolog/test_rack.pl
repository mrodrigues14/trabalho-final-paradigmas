:- use_module(rack).
:- use_module(library(plunit)).

vazio([[0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0]]).

solucao_exemplo([[1, 0, 0, 1, 0, 0],
                 [0, 0, 1, 0, 0, 1],
                 [1, 0, 0, 0, 1, 0],
                 [0, 1, 0, 0, 0, 0],
                 [0, 0, 0, 1, 0, 1],
                 [1, 0, 1, 0, 0, 0]]).

:- begin_tests(resolver).

test(exemplo, true(S == Esperada)) :-
    puzzle_exemplo(P),
    vazio(M),
    solucao_exemplo(Esperada),
    once(resolver(P, M, S)).

test(exemplo_unico, true(N == 1)) :-
    puzzle_exemplo(P),
    contar_solucoes(P, 2, N).

test(sem_sensores_varias_solucoes, true(N == 2)) :-
    contar_solucoes(puzzle(2, 2, [1, 1], [1, 1], []), 10, N).

test(carga_impossivel, fail) :-
    resolver(puzzle(1, 3, [3], [1, 1, 1], []), [[0, 0, 0]], _).

test(linha_com_carga_zero, true(S == [[0, 0, 0]])) :-
    once(resolver(puzzle(1, 3, [0], [0, 0, 0], []), [[0, 0, 0]], S)).

test(servidores_encostados, fail) :-
    resolver(puzzle(1, 2, [2], [1, 1], []), [[0, 0]], _).

:- end_tests(resolver).

:- begin_tests(sensores).

test(sensor_no_canto, true(S == [[0, 1], [1, 0]])) :-
    once(resolver(puzzle(2, 2, [1, 1], [1, 1], [[0, 0, 2]]), [[0, 0], [0, 0]], S)).

test(sensor_no_canto_impossivel, fail) :-
    resolver(puzzle(2, 2, [1, 1], [1, 1], [[0, 0, 1]]), [[0, 0], [0, 0]], _).

test(sensor_zero, true(S == [[1, 0, 0], [0, 0, 0]])) :-
    once(resolver(puzzle(2, 3, [1, 0], [1, 0, 0], [[1, 2, 0]]), [[0, 0, 0], [0, 0, 0]], S)).

test(sensor_nao_tem_servidor, fail) :-
    resolver(puzzle(1, 1, [1], [1], [[0, 0, 0]]), [[0]], _).

:- end_tests(sensores).

:- begin_tests(marcas).

test(marca_certa, true(S == Esperada)) :-
    puzzle_exemplo(P),
    solucao_exemplo(Esperada),
    M = [[1, 2, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0]],
    once(resolver(P, M, S)).

test(marca_errada, fail) :-
    puzzle_exemplo(P),
    M = [[2, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0]],
    resolver(P, M, _).

:- end_tests(marcas).
