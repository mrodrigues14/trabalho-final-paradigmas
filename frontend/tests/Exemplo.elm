module Exemplo exposing (puzzle, solucao)

{-| O mesmo puzzle de `puzzle_exemplo/1` (backend/prolog/rack.pl) e a
solução única que o `test_rack.pl` confere. Usar o mesmo exemplo nos dois
lados garante que as regras do Elm e do Prolog concordam.
-}

import Rack exposing (Posicao, Puzzle)


puzzle : Puzzle
puzzle =
    Rack.criar 6
        6
        [ 2, 2, 2, 1, 2, 2 ]
        [ 3, 1, 2, 2, 1, 2 ]
        [ ( Posicao 1 4, 3 )
        , ( Posicao 2 1, 3 )
        , ( Posicao 3 0, 2 )
        , ( Posicao 3 2, 2 )
        , ( Posicao 4 2, 3 )
        ]


solucao : List (List Int)
solucao =
    [ [ 1, 0, 0, 1, 0, 0 ]
    , [ 0, 0, 1, 0, 0, 1 ]
    , [ 1, 0, 0, 0, 1, 0 ]
    , [ 0, 1, 0, 0, 0, 0 ]
    , [ 0, 0, 0, 1, 0, 1 ]
    , [ 1, 0, 1, 0, 0, 0 ]
    ]
