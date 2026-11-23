:- use_module(gerador).
:- use_module(dica).
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

% A solução do puzzle_exemplo/1 do rack.pl (a mesma do test_rack.pl).
solucao_exemplo([[1, 0, 0, 1, 0, 0],
                 [0, 0, 1, 0, 0, 1],
                 [1, 0, 0, 0, 1, 0],
                 [0, 1, 0, 0, 0, 0],
                 [0, 0, 0, 1, 0, 1],
                 [1, 0, 1, 0, 0, 0]]).

valor(Grade, R, C, X) :-
    nth0(R, Grade, Linha),
    nth0(C, Linha, X).

% O motivo aponta para uma regra que passa pela casa da dica.
motivo_coerente([R, C, V, Motivo], Puzzle, Marcas) :-
    coerente(Motivo, R, C, V, Puzzle, Marcas).

% O motivo vem no primeiro argumento para a indexação escolher a cláusula
% sem deixar ponto de escolha.
coerente(linha(R), R, _, _, _, _).
coerente(coluna(C), _, C, _, _, _).
coerente(sensor(SR, SC), R, C, _, puzzle(_, _, _, _, Sensores), _) :-
    memberchk([SR, SC, _], Sensores),
    abs(SR - R) =< 1,
    abs(SC - C) =< 1.
coerente(refrigeracao(R2, C2), R, C, 0, _, Marcas) :-
    abs(R2 - R) + abs(C2 - C) =:= 1,
    valor(Marcas, R2, C2, 1).
coerente(combinado, _, _, _, _, _).

:- begin_tests(dica).

test(por_linha, true(D == [0, 0, 0, linha(0)])) :-
    dica(puzzle(1, 3, [0], [0, 0, 0], []), [[0, 0, 0]], D).

test(por_coluna, true(D == [0, 1, 0, coluna(1)])) :-
    marcas_vazias(3, 2, M),
    dica(puzzle(3, 2, [1, 0, 1], [2, 0], []), M, D).

test(por_sensor, true(D == [0, 1, 0, sensor(0, 0)])) :-
    marcas_vazias(3, 3, M),
    dica(puzzle(3, 3, [1, 0, 1], [0, 1, 1], [[0, 0, 0]]), M, D).

test(por_refrigeracao, true(D == [0, 0, 0, refrigeracao(1, 0)])) :-
    dica(puzzle(4, 2, [1, 1, 0, 1], [2, 1], []),
         [[0, 0],
          [1, 0],
          [0, 0],
          [0, 0]], D).

% Nenhuma regra sozinha força nada: a linha 0 pede 2 servidores em 3
% casas, e só a refrigeração junto com ela obriga o padrão 1 0 1.
test(combinado, true(D == [0, 0, 1, combinado])) :-
    marcas_vazias(2, 3, M),
    dica(puzzle(2, 3, [2, 1], [1, 1, 1], []), M, D).

test(tabuleiro_completo, fail) :-
    dica(puzzle(2, 3, [2, 1], [1, 1, 1], []), [[1, 2, 1], [2, 1, 2]], _).

test(marcas_em_contradicao, fail) :-
    puzzle_exemplo(P),
    dica(P, [[2, 0, 0, 0, 0, 0],
             [0, 0, 0, 0, 0, 0],
             [0, 0, 0, 0, 0, 0],
             [0, 0, 0, 0, 0, 0],
             [0, 0, 0, 0, 0, 0],
             [0, 0, 0, 0, 0, 0]], _).

test(bate_com_a_solucao_do_exemplo, true(V == Esperado)) :-
    puzzle_exemplo(P),
    marcas_vazias(6, 6, M),
    dica(P, M, [R, C, V, _]),
    solucao_exemplo(S),
    valor(S, R, C, Esperado).

test(ignora_casas_ja_marcadas, true(Marca == 0)) :-
    puzzle_exemplo(P),
    M = [[1, 2, 2, 1, 2, 2],
         [2, 2, 1, 2, 0, 1],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0]],
    dica(P, M, [R, C, _, _]),
    valor(M, R, C, Marca).

test(bate_com_a_solucao_gerada, [forall(member(Nivel, [facil, medio, dificil]))]) :-
    gerar(Nivel, P),
    P = puzzle(L, C, _, _, Sensores),
    marcas_vazias(L, C, M),
    once(resolver(P, M, S)),
    dica(P, M, Dica),
    Dica = [R, Col, V, _],
    valor(S, R, Col, V),
    \+ memberchk([R, Col, _], Sensores),
    motivo_coerente(Dica, P, M).

:- end_tests(dica).

% Refaz os passos de resolver_com_dicas/3 a partir de Marcas0, conferindo
% cada dica contra a solução e contra as marcas do momento, e devolve as
% marcas do fim. A lista de passos vem primeiro para a indexação escolher
% a cláusula sem deixar ponto de escolha.
seguir_passos([], _, _, Marcas, Marcas).
seguir_passos([Dica | Passos], Puzzle, Solucao, Marcas0, Marcas) :-
    Dica = [R, C, V, _],
    valor(Marcas0, R, C, 0),
    valor(Solucao, R, C, V),
    motivo_coerente(Dica, Puzzle, Marcas0),
    dica:marcar(Marcas0, R, C, V, Marcas1),
    seguir_passos(Passos, Puzzle, Solucao, Marcas1, Marcas).

% Marca de jogador que corresponde a cada valor da solução.
marca_da_solucao(1, 1).
marca_da_solucao(0, 2).

% Toda casa termina marcada de acordo com a solução (sensor fica 0).
completo(puzzle(_, _, _, _, Sensores), Solucao, Marcas) :-
    forall(( nth0(R, Solucao, Linha), nth0(C, Linha, V) ),
           (   memberchk([R, C, _], Sensores)
           ->  valor(Marcas, R, C, 0)
           ;   marca_da_solucao(V, Marca),
               valor(Marcas, R, C, Marca)
           )).

:- begin_tests(resolver_com_dicas).

test(exemplo_tem_um_passo_por_casa_aberta, true(N == 31)) :-
    puzzle_exemplo(P),
    marcas_vazias(6, 6, M),
    resolver_com_dicas(P, M, Passos),
    length(Passos, N).

test(exemplo_cada_passo_certo_e_explicado) :-
    puzzle_exemplo(P),
    solucao_exemplo(S),
    marcas_vazias(6, 6, M),
    resolver_com_dicas(P, M, Passos),
    seguir_passos(Passos, P, S, M, Final),
    completo(P, S, Final).

test(gerado_resolvido_so_com_dicas, [forall(between(1, 3, _))]) :-
    gerar(facil, P),
    marcas_vazias(6, 6, M),
    once(resolver(P, M, S)),
    resolver_com_dicas(P, M, Passos),
    seguir_passos(Passos, P, S, M, Final),
    completo(P, S, Final).

% As duas primeiras linhas já marcadas; (1, 4) é sensor e fica 0.
test(continua_de_onde_o_jogador_parou, true(N == 20)) :-
    puzzle_exemplo(P),
    solucao_exemplo(S),
    M = [[1, 2, 2, 1, 2, 2],
         [2, 2, 1, 2, 0, 1],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0],
         [0, 0, 0, 0, 0, 0]],
    resolver_com_dicas(P, M, Passos),
    seguir_passos(Passos, P, S, M, Final),
    completo(P, S, Final),
    length(Passos, N).

test(tabuleiro_completo_nao_tem_passos, true(Passos == [])) :-
    resolver_com_dicas(puzzle(2, 3, [2, 1], [1, 1, 1], []),
                       [[1, 2, 1], [2, 1, 2]], Passos).

:- end_tests(resolver_com_dicas).

:- begin_tests(dificuldade).

% Com sensor em toda casa livre, cada linha só tem servidores abertos: a
% carga da linha força tudo, sem combinar regras.
test(todas_as_pistas_e_facil, [forall(between(1, 3, _)), true(N == facil)]) :-
    solucao_aleatoria(6, 6, G),
    derivar_pistas(G, P),
    dificuldade(P, N).

% 4 passos combinados em 31 (13%).
test(exemplo_e_medio, true(N == medio)) :-
    puzzle_exemplo(P),
    dificuldade(P, N).

% 1 passo combinado em 6 (17%).
test(combinado_e_dificil, true(N == dificil)) :-
    dificuldade(puzzle(2, 3, [2, 1], [1, 1, 1], []), N).

test(gerado_tem_nivel, [forall(between(1, 3, _))]) :-
    gerar(facil, P),
    dificuldade(P, N),
    memberchk(N, [facil, medio, dificil]).

:- end_tests(dificuldade).
