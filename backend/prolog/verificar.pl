/*  verificar.pl: verificação das marcas do jogador no Rack.

    A interface em Elm já acusa na hora os conflitos locais (linha ou
    coluna excedida, sensor excedido, servidores encostados). O que ela não
    vê são marcas que respeitam as regras até ali mas não levam à solução.
    É isso que verificar/3 aponta, comparando as marcas com a solução.

    COMO TESTAR NO TERMINAL
    -----------------------
        $ swipl backend/prolog/verificar.pl
        ?- rack:puzzle_exemplo(P),
           verificar(P, [[2,1,0,0,0,0],[0,0,0,0,0,0],[0,0,0,0,0,0],
                         [0,0,0,0,0,0],[0,0,0,0,0,0],[0,0,0,0,0,0]], R).
        R = contradicao([[0, 0], [0, 1]]).
*/

:- module(verificar,
          [ verificar/3              % +Puzzle, +Marcas, -Resultado
          ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(rack).


%!  verificar(+Puzzle, +Marcas, -Resultado) is semidet.
%
%   Resultado é `ok` se nenhuma marca contradiz a solução, ou
%   contradicao(Casas), com Casas = [[R, C], ...] em ordem de linha e
%   coluna. Falha se o puzzle não tem solução.
%
%   Comparar com a solução é válido porque todo puzzle de gerar/2 tem
%   solução ÚNICA (enxugar/2 só retira um sensor se contar_solucoes/3
%   continuar dando 1): uma marca está errada exatamente quando difere da
%   única solução. Num puzzle com mais de uma solução, a comparação seria
%   com a primeira que resolver/3 encontrar, e uma marca que vale em outra
%   solução seria acusada como errada.
verificar(Puzzle, Marcas, Resultado) :-
    marcas_vazias(Puzzle, Vazias),
    once(resolver(Puzzle, Vazias, Solucao)),
    findall([R, C], marca_errada(Marcas, Solucao, R, C), Casas),
    resultado(Casas, Resultado).

resultado([], ok).
resultado([Casa | Casas], contradicao([Casa | Casas])).

%!  marca_errada(+Marcas, +Solucao, -R, -C) is nondet.
%
%   A marca do jogador na casa (R, C) contradiz a solução. O nth0/3 com R
%   e C livres percorre as casas em ordem de linha e coluna.
marca_errada(Marcas, Solucao, R, C) :-
    nth0(R, Marcas, LinhaMarcas),
    nth0(R, Solucao, LinhaSolucao),
    nth0(C, LinhaMarcas, Marca),
    nth0(C, LinhaSolucao, Valor),
    contradiz(Marca, Valor).

%!  contradiz(?Marca, ?Valor) is nondet.
%
%   Servidor (marca 1) onde a solução tem casa livre, ou livre (marca 2)
%   onde a solução tem servidor. A marca 0 nunca contradiz nada.
contradiz(1, 0).
contradiz(2, 1).

%!  marcas_vazias(+Puzzle, -Marcas) is det.
marcas_vazias(puzzle(L, C, _, _, _), Marcas) :-
    length(Marcas, L),
    maplist(linha_vazia(C), Marcas).

linha_vazia(C, Linha) :-
    length(Linha, C),
    maplist(=(0), Linha).
