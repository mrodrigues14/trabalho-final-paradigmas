module Simulado exposing (gerar, pedirDica, resolver)

import Process
import Rack exposing (Casa(..), Dica, Dificuldade, Marca(..), Motivo(..), Posicao, Puzzle)
import Task


solucao : List (List Int)
solucao =
    [ [ 1, 0, 1, 0, 0, 1 ]
    , [ 0, 0, 0, 1, 0, 0 ]
    , [ 1, 0, 0, 0, 0, 1 ]
    , [ 0, 1, 0, 1, 0, 0 ]
    , [ 0, 0, 0, 0, 0, 1 ]
    , [ 1, 0, 1, 0, 0, 0 ]
    ]


puzzleFixo : Puzzle
puzzleFixo =
    Rack.criar 6
        6
        [ 3, 1, 2, 2, 1, 2 ]
        [ 3, 1, 2, 2, 0, 3 ]
        [ ( Posicao 1 1, 3 ), ( Posicao 2 4, 3 ), ( Posicao 4 3, 2 ), ( Posicao 5 5, 1 ) ]


responder : (Result String a -> msg) -> Result String a -> Cmd msg
responder paraMsg resultado =
    Process.sleep 400 |> Task.perform (\_ -> paraMsg resultado)


gerar : Dificuldade -> (Result String Puzzle -> msg) -> Cmd msg
gerar _ paraMsg =
    responder paraMsg (Ok puzzleFixo)


pedirDica : Puzzle -> (Result String Dica -> msg) -> Cmd msg
pedirDica puzzle paraMsg =
    let
        casasDaSolucao =
            solucao
                |> List.indexedMap (\l -> List.indexedMap (\c v -> ( Posicao l c, v )))
                |> List.concat

        candidata =
            casasDaSolucao
                |> List.filter (\( p, _ ) -> Rack.casaEm p puzzle == Just (Aberta SemMarca))
                |> List.head
    in
    case candidata of
        Just ( p, v ) ->
            responder paraMsg
                (Ok
                    { posicao = p
                    , valor =
                        if v == 1 then
                            Servidor

                        else
                            Livre
                    , motivo = PorLinha p.linha
                    }
                )

        Nothing ->
            responder paraMsg (Err "O tabuleiro já está completo.")


resolver : Puzzle -> (Result String (List (List Int)) -> msg) -> Cmd msg
resolver _ paraMsg =
    responder paraMsg (Ok solucao)
