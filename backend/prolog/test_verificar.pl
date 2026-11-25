:- use_module(verificar).
:- use_module(rack).
:- use_module(library(plunit)).

vazio([[0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0]]).

% A solução de puzzle_exemplo/1 escrita como marcas: 1 servidor, 2 livre.
marcas_solucao([[1, 2, 2, 1, 2, 2],
                [2, 2, 1, 2, 2, 1],
                [1, 2, 2, 2, 1, 2],
                [2, 1, 2, 2, 2, 2],
                [2, 2, 2, 1, 2, 1],
                [1, 2, 1, 2, 2, 2]]).

:- begin_tests(verificar).

test(marcas_vazias, true(R == ok)) :-
    puzzle_exemplo(P),
    vazio(M),
    verificar(P, M, R).

test(marcas_da_solucao, true(R == ok)) :-
    puzzle_exemplo(P),
    marcas_solucao(M),
    verificar(P, M, R).

test(marcas_parciais_certas, true(R == ok)) :-
    puzzle_exemplo(P),
    M = [[1, 2, 2, 1, 2, 2],
         [0, 0, 1, 0, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 2]],
    verificar(P, M, R).

test(servidor_errado, true(R == contradicao([[0, 1]]))) :-
    puzzle_exemplo(P),
    M = [[1, 1, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0]],
    verificar(P, M, R).

test(livre_errado, true(R == contradicao([[0, 0]]))) :-
    puzzle_exemplo(P),
    M = [[2, 2, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0]],
    verificar(P, M, R).

test(varios_erros_em_ordem, true(R == contradicao([[0, 0], [2, 3], [5, 5]]))) :-
    puzzle_exemplo(P),
    M = [[2, 2, 0, 1, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 1, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 1]],
    verificar(P, M, R).

:- end_tests(verificar).
