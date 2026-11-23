:- module(rack, [rack_restricoes/2, aplicar_marcas/2, resolver/3,
                 contar_solucoes/3, puzzle_exemplo/1, imprimir/2]).

:- use_module(library(clpfd)).

rack_restricoes(puzzle(L, C, CargasLinha, CargasColuna, Sensores), Grade) :-
    length(Grade, L),
    maplist(tamanho(C), Grade),
    append(Grade, Casas),
    Casas ins 0..1,
    maplist(soma_igual, Grade, CargasLinha),
    transpose(Grade, Colunas),
    maplist(soma_igual, Colunas, CargasColuna),
    maplist(sensor(Grade), Sensores),
    maplist(sem_encostar, Grade),
    maplist(sem_encostar, Colunas).

tamanho(N, Lista) :-
    length(Lista, N).

soma_igual(Fileira, N) :-
    sum(Fileira, #=, N).

casa(Grade, R, C, X) :-
    nth0(R, Grade, Linha),
    nth0(C, Linha, X).

sensor(Grade, [R, C, N]) :-
    casa(Grade, R, C, X),
    X #= 0,
    vizinhos(Grade, R, C, Vizinhos),
    sum(Vizinhos, #=, N).

vizinhos(Grade, R, C, Vizinhos) :-
    findall(R1-C1, posicao_vizinha(Grade, R, C, R1, C1), Posicoes),
    maplist(casa_na_posicao(Grade), Posicoes, Vizinhos).

posicao_vizinha(Grade, R, C, R1, C1) :-
    length(Grade, L),
    Grade = [Linha | _],
    length(Linha, NC),
    member(DR, [-1, 0, 1]),
    member(DC, [-1, 0, 1]),
    DR-DC \== 0-0,
    R1 is R + DR,
    C1 is C + DC,
    R1 >= 0, R1 < L,
    C1 >= 0, C1 < NC.

casa_na_posicao(Grade, R-C, X) :-
    casa(Grade, R, C, X).

sem_encostar([]).
sem_encostar([_]).
sem_encostar([A, B | Resto]) :-
    A + B #=< 1,
    sem_encostar([B | Resto]).

aplicar_marcas(Grade, Marcas) :-
    maplist(maplist(marca), Grade, Marcas).

marca(_, 0).
marca(1, 1).
marca(0, 2).

resolver(Puzzle, Marcas, Solucao) :-
    rack_restricoes(Puzzle, Solucao),
    aplicar_marcas(Solucao, Marcas),
    append(Solucao, Casas),
    label(Casas).

contar_solucoes(Puzzle, Limite, N) :-
    findall(Grade,
            limit(Limite, (rack_restricoes(Puzzle, Grade),
                           append(Grade, Casas),
                           label(Casas))),
            Solucoes),
    length(Solucoes, N).

puzzle_exemplo(puzzle(6, 6,
                      [2, 2, 2, 1, 2, 2],
                      [3, 1, 2, 2, 1, 2],
                      [[1, 4, 3], [2, 1, 3], [3, 0, 2], [3, 2, 2], [4, 2, 3]])).

imprimir(puzzle(_, _, _, _, Sensores), Grade) :-
    forall(nth0(R, Grade, Linha),
           ( forall(nth0(C, Linha, X), imprimir_casa(Sensores, R, C, X)),
             nl )).

imprimir_casa(Sensores, R, C, _) :-
    member([R, C, N], Sensores),
    !,
    format(" ~w", [N]).
imprimir_casa(_, _, _, 1) :-
    !,
    write(" #").
imprimir_casa(_, _, _, _) :-
    write(" .").
