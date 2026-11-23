/*  dica.pl: dicas explicadas para o Rack.

    Uma dica é uma casa aberta cujo valor já está FORÇADO, junto com o
    motivo. A pergunta que o Prolog responde é:

        "Se esta casa tivesse o valor oposto, alguma regra ficaria
         impossível sozinha?"

    Se sim, a casa só pode ter o valor da dica, e a regra que ficaria
    impossível é o motivo. Para cada casa aberta, testamos cada regra que
    passa por ela, uma por vez. Se nenhuma regra sozinha decide nada, a dica
    vem da combinação de todas as regras (motivo `combinado`).

    Formato: dica(+Puzzle, +Marcas, -[Linha, Coluna, Valor, Motivo]), em que
    Valor é 1 (servidor) ou 0 (livre) e Motivo é um destes termos:

        linha(I)              a carga da linha I
        coluna(J)             a carga da coluna J
        sensor(R, C)          o sensor na casa (R, C)
        refrigeracao(R, C)    o servidor vizinho, na casa (R, C)
        combinado             foi preciso juntar todas as regras

    Aplicando dicas em sequência, o próprio Prolog resolve o puzzle passo a
    passo (resolver_com_dicas/3). Contar quantos passos precisaram do caso
    `combinado` mede a dificuldade pelo raciocínio (dificuldade/2), e não
    só pelo tamanho da grade.

    COMO TESTAR NO TERMINAL
    -----------------------
        $ swipl backend/prolog/dica.pl
        ?- rack:puzzle_exemplo(P), length(M, 6),
           maplist([L]>>(length(L, 6), maplist(=(0), L)), M),
           dica(P, M, D).
        ?- rack:puzzle_exemplo(P), dificuldade(P, N).
*/

:- module(dica,
          [ dica/3,                  % +Puzzle, +Marcas, -Dica
            resolver_com_dicas/3,    % +Puzzle, +Marcas, -Passos
            dificuldade/2            % +Puzzle, -Nivel
          ]).

:- use_module(library(clpfd)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(aggregate)).
:- use_module(rack).


/* =========================================================================
   1. A DICA
   ========================================================================= */

%!  dica(+Puzzle, +Marcas, -Dica) is semidet.
%
%   Dica = [R, C, V, Motivo]: a casa aberta (R, C) só pode valer V.
%   Falha se o tabuleiro já estiver completo ou se as marcas estiverem em
%   contradição (nesses casos a API responde 422).
%
%   O resolver/3 do começo é a guarda contra marcas erradas: se as marcas
%   ainda levam a uma solução, toda dica dada aqui bate com ela.
%
%   O "Se -> Então ; Senão" fica com a PRIMEIRA casa forçada por uma regra
%   (o -> descarta as demais, como um corte) e só cai no caso combinado se
%   não houver nenhuma.
dica(Puzzle, Marcas, Dica) :-
    once(resolver(Puzzle, Marcas, Solucao)),
    grade_base(Puzzle, Marcas, Grade),
    (   forcada_por_uma_regra(Puzzle, Marcas, Grade, Dica)
    ->  true
    ;   forcada_pela_combinacao(Puzzle, Marcas, Solucao, Dica)
    ).

%!  forcada_por_uma_regra(+Puzzle, +Marcas, +Grade, -Dica) is nondet.
%
%   Enumera, por backtracking, casa aberta, valor e regra. A casa está
%   forçada em V se o valor oposto torna a regra impossível.
%
%   O \+ ("não é demonstrável") tem dois papéis: é a negação da frase
%   "existe uma forma de satisfazer a regra com o valor oposto", e desfaz
%   tudo o que consistente/5 fez. As restrições postas lá dentro somem ao
%   sair, então a mesma Grade serve para todas as tentativas.
forcada_por_uma_regra(Puzzle, Marcas, Grade, [R, C, V, Motivo]) :-
    casa_aberta(Puzzle, Marcas, R, C),
    member(V, [1, 0]),
    Oposto is 1 - V,
    regra(Puzzle, Grade, R, C, Regra),
    \+ consistente(Grade, Regra, R, C, Oposto),
    motivo(Regra, Motivo).

%!  forcada_pela_combinacao(+Puzzle, +Marcas, +Solucao, -Dica) is semidet.
%
%   Nenhuma regra sozinha decide. Pegamos a primeira casa aberta em que o
%   valor oposto ao da solução deixa o puzzle inteiro sem solução.
forcada_pela_combinacao(Puzzle, Marcas, Solucao, [R, C, V, combinado]) :-
    casa_aberta(Puzzle, Marcas, R, C),
    casa(Solucao, R, C, V),
    Oposto is 1 - V,
    marcar(Marcas, R, C, Oposto, MarcasOpostas),
    \+ resolver(Puzzle, MarcasOpostas, _),
    !.


/* =========================================================================
   2. A GRADE BASE
   ========================================================================= */

%!  grade_base(+Puzzle, +Marcas, -Grade) is det.
%
%   Uma variável 0..1 por casa, com as marcas do jogador aplicadas e as
%   casas de sensor valendo 0. NENHUMA regra do jogo entra aqui: cada regra
%   é posta sozinha por consistente/5. O 0 do sensor não conta como regra
%   porque faz parte do tabuleiro (o jogador nem consegue marcar ali).
grade_base(puzzle(_, _, _, _, Sensores), Marcas, Grade) :-
    once(aplicar_marcas(Grade, Marcas)),
    append(Grade, Casas),
    Casas ins 0..1,
    maplist(casa_de_sensor(Grade), Sensores).

casa_de_sensor(Grade, [R, C, _]) :-
    casa(Grade, R, C, 0).

%!  casa_aberta(+Puzzle, +Marcas, -R, -C) is nondet.
%
%   (R, C) não tem marca do jogador e não é casa de sensor.
casa_aberta(puzzle(_, _, _, _, Sensores), Marcas, R, C) :-
    nth0(R, Marcas, Linha),
    nth0(C, Linha, 0),
    \+ memberchk([R, C, _], Sensores).

casa(Grade, R, C, X) :-
    nth0(R, Grade, Linha),
    nth0(C, Linha, X).

%!  marcar(+Marcas0, +R, +C, +Valor, -Marcas) is det.
%
%   Marcas é Marcas0 com a casa (R, C) marcada com Valor (1 vira a marca 1,
%   servidor; 0 vira a marca 2, livre). Nada muda no lugar: nth0/4 tira a
%   linha e a casa antigas e, usado ao contrário, encaixa as novas.
marcar(Marcas0, R, C, Valor, Marcas) :-
    valor_marca(Valor, Marca),
    nth0(R, Marcas0, Linha0, OutrasLinhas),
    nth0(C, Linha0, _, OutrasCasas),
    nth0(C, Linha, Marca, OutrasCasas),
    nth0(R, Marcas, Linha, OutrasLinhas).

valor_marca(1, 1).
valor_marca(0, 2).

%!  marcas_vazias(+Puzzle, -Marcas) is det.
marcas_vazias(puzzle(L, C, _, _, _), Marcas) :-
    length(Marcas, L),
    maplist(linha_vazia(C), Marcas).

linha_vazia(C, Linha) :-
    length(Linha, C),
    maplist(=(0), Linha).


/* =========================================================================
   3. AS REGRAS, UMA DE CADA VEZ
   ========================================================================= */

%!  regra(+Puzzle, +Grade, +R, +C, -Regra) is nondet.
%
%   Enumera as regras que passam pela casa (R, C), na ordem em que a dica
%   prefere explicar: a linha, a coluna, os sensores em volta e os vizinhos
%   laterais (refrigeração).
regra(puzzle(_, _, CargasLinha, _, _), _, R, _, linha(R, N)) :-
    nth0(R, CargasLinha, N).
regra(puzzle(_, _, _, CargasColuna, _), _, _, C, coluna(C, N)) :-
    nth0(C, CargasColuna, N).
regra(puzzle(_, _, _, _, Sensores), _, R, C, sensor(SR, SC, N)) :-
    member([SR, SC, N], Sensores),
    abs(SR - R) =< 1,
    abs(SC - C) =< 1.
regra(_, Grade, R, C, refrigeracao(R, C, R2, C2)) :-
    posicao_ao_lado(Grade, R, C, R2, C2).

%!  consistente(+Grade, +Regra, +R, +C, +Valor) is semidet.
%
%   Existe uma forma de preencher as casas da Regra que a satisfaz com a
%   casa (R, C) valendo Valor. Só aquela regra é posta; label/1 rotula só
%   as casas dela, que são poucas (no máximo 10).
consistente(Grade, Regra, R, C, Valor) :-
    casa(Grade, R, C, Valor),
    restricao(Regra, Grade, Casas),
    label(Casas).

%!  restricao(+Regra, +Grade, -Casas) is det.
%
%   Posta a restrição da Regra e devolve as casas envolvidas.
restricao(linha(R, N), Grade, Linha) :-
    nth0(R, Grade, Linha),
    sum(Linha, #=, N).
restricao(coluna(C, N), Grade, Coluna) :-
    maplist(nth0(C), Grade, Coluna),
    sum(Coluna, #=, N).
restricao(sensor(R, C, N), Grade, Vizinhas) :-
    findall(R1-C1, posicao_em_volta(Grade, R, C, R1, C1), Posicoes),
    maplist(casa_na_posicao(Grade), Posicoes, Vizinhas),
    sum(Vizinhas, #=, N).
restricao(refrigeracao(R, C, R2, C2), Grade, [A, B]) :-
    casa(Grade, R, C, A),
    casa(Grade, R2, C2, B),
    A + B #=< 1.

%   O findall/3 junta POSIÇÕES, e não as casas: ele copia os termos, e uma
%   cópia de uma variável do CLP(FD) seria outra variável, sem as marcas.
casa_na_posicao(Grade, R-C, X) :-
    casa(Grade, R, C, X).

%!  posicao_em_volta(+Grade, +R, +C, -R1, -C1) is nondet.
%
%   (R1, C1) é uma das até 8 casas em volta de (R, C). Como em
%   gerador.pl, os limites da grade saem de graça: nth0/3 só gera índices
%   que existem.
posicao_em_volta(Grade, R, C, R1, C1) :-
    nth0(R1, Grade, Linha),
    abs(R1 - R) =< 1,
    nth0(C1, Linha, _),
    abs(C1 - C) =< 1,
    R1-C1 \== R-C.

%!  posicao_ao_lado(+Grade, +R, +C, -R2, -C2) is nondet.
%
%   (R2, C2) encosta em (R, C) por um lado: distância de Manhattan 1.
posicao_ao_lado(Grade, R, C, R2, C2) :-
    nth0(R2, Grade, Linha),
    nth0(C2, Linha, _),
    abs(R2 - R) + abs(C2 - C) =:= 1.

%!  motivo(+Regra, -Motivo) is det.
%
%   O que a dica mostra ao jogador: só o necessário para achar a regra
%   no tabuleiro.
motivo(linha(R, _), linha(R)).
motivo(coluna(C, _), coluna(C)).
motivo(sensor(R, C, _), sensor(R, C)).
motivo(refrigeracao(_, _, R2, C2), refrigeracao(R2, C2)).


/* =========================================================================
   4. RESOLVER SÓ COM DICAS E MEDIR A DIFICULDADE
   ========================================================================= */

%!  resolver_com_dicas(+Puzzle, +Marcas, -Passos) is det.
%
%   Passos é a sequência de dicas que leva das Marcas até o tabuleiro
%   completo, como se o jogador seguisse cada dica. Cada passo marca a casa
%   da dica e chama a si mesmo com as marcas NOVAS (recursão no lugar de
%   laço; nada é alterado no lugar). Quando não há mais dica, a lista acaba.
%
%   O "Se -> Então ; Senão" garante uma resposta só: havendo dica, ela é
%   seguida; o ramo da lista vazia não é tentado no backtracking.
resolver_com_dicas(Puzzle, Marcas, Passos) :-
    (   dica(Puzzle, Marcas, Dica)
    ->  Dica = [R, C, V, _],
        marcar(Marcas, R, C, V, MarcasSeguintes),
        Passos = [Dica | Resto],
        resolver_com_dicas(Puzzle, MarcasSeguintes, Resto)
    ;   Passos = []
    ).

%!  porcentagem_combinada(?Nivel, ?Maximo) is nondet.
%
%   Qual porcentagem dos passos pode precisar do caso `combinado` em cada
%   nível. Fácil é o que dá para resolver só com dicas de uma regra; acima
%   do último limiar, o puzzle é difícil. Usamos a PROPORÇÃO e não o número
%   de passos combinados porque esse número cresce com a grade: medindo os
%   puzzles gerados, um 6x6 teve de 0 a 4 passos combinados em 26, um 8x8
%   de 8 a 13 em 54 e um 10x10 de 14 a 16 em 80.
porcentagem_combinada(facil, 0).
porcentagem_combinada(medio, 15).

%!  dificuldade(+Puzzle, -Nivel) is det.
%
%   Resolve o puzzle do zero só com dicas e mede o nível pela proporção de
%   passos em que foi preciso combinar as regras.
dificuldade(Puzzle, Nivel) :-
    marcas_vazias(Puzzle, Marcas),
    resolver_com_dicas(Puzzle, Marcas, Passos),
    length(Passos, Total),
    aggregate_all(count, member([_, _, _, combinado], Passos), Combinados),
    nivel_por_combinados(Combinados, Total, Nivel).

%   Os fatos de porcentagem_combinada/2 estão do mais fácil para o mais
%   difícil, então o primeiro limiar que cabe é o nível certo. A conta fica
%   em inteiros: Combinados/Total =< Maximo/100.
nivel_por_combinados(Combinados, Total, Nivel) :-
    (   porcentagem_combinada(Nivel0, Maximo),
        Combinados * 100 =< Maximo * Total
    ->  Nivel = Nivel0
    ;   Nivel = dificil
    ).
