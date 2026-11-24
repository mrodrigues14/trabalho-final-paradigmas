module RackTest exposing (suite)

import Exemplo
import Expect
import Fuzz
import Rack exposing (Casa(..), Conflito(..), Marca(..), Motivo(..), Posicao)
import Test exposing (Test, describe, fuzz2, test)


suite : Test
suite =
    describe "Rack"
        [ marcas
        , conflitos
        , vitoria
        , textos
        ]


{-| Marca servidor em cada posição da lista.
-}
comServidores : List Posicao -> Rack.Puzzle -> Rack.Puzzle
comServidores lista puzzle =
    List.foldl (\posicao -> Rack.marcar posicao Servidor) puzzle lista


marcas : Test
marcas =
    let
        canto =
            Posicao 0 0

        sensor =
            Posicao 1 4
    in
    describe "marcas"
        [ test "o clique segue o ciclo sem marca, servidor, livre, sem marca" <|
            \_ ->
                List.map (\vezes -> Rack.casaEm canto (repetir vezes (Rack.alternar canto) Exemplo.puzzle))
                    [ 0, 1, 2, 3 ]
                    |> Expect.equal
                        [ Just (Aberta SemMarca)
                        , Just (Aberta Servidor)
                        , Just (Aberta Livre)
                        , Just (Aberta SemMarca)
                        ]
        , fuzz2 (Fuzz.intRange 0 5) (Fuzz.intRange 0 5) "três cliques na mesma casa voltam ao tabuleiro inicial" <|
            \linha coluna ->
                repetir 3 (Rack.alternar (Posicao linha coluna)) Exemplo.puzzle
                    |> Expect.equal Exemplo.puzzle
        , test "clicar num sensor não muda nada" <|
            \_ ->
                Rack.alternar sensor Exemplo.puzzle
                    |> Expect.equal Exemplo.puzzle
        , test "marcar um sensor não muda nada" <|
            \_ ->
                Rack.marcar sensor Servidor Exemplo.puzzle
                    |> Expect.equal Exemplo.puzzle
        , test "marcar fora da grade não muda nada" <|
            \_ ->
                Rack.marcar (Posicao 6 0) Servidor Exemplo.puzzle
                    |> Expect.equal Exemplo.puzzle
        , test "a dica marca a casa com o valor dela" <|
            \_ ->
                Rack.aplicarDica { posicao = canto, valor = Livre, motivo = Combinado } Exemplo.puzzle
                    |> Rack.casaEm canto
                    |> Expect.equal (Just (Aberta Livre))
        , test "a solução marca as casas abertas e preserva os sensores" <|
            \_ ->
                let
                    resolvido =
                        Rack.aplicarSolucao Exemplo.solucao Exemplo.puzzle
                in
                List.map (\posicao -> Rack.casaEm posicao resolvido) [ canto, Posicao 0 1, sensor ]
                    |> Expect.equal [ Just (Aberta Servidor), Just (Aberta Livre), Just (Sensor 3) ]
        , test "contagem de servidores por linha e por coluna" <|
            \_ ->
                let
                    resolvido =
                        Rack.aplicarSolucao Exemplo.solucao Exemplo.puzzle
                in
                ( Rack.servidoresNaLinha 3 resolvido, Rack.servidoresNaColuna 0 resolvido )
                    |> Expect.equal ( 1, 3 )
        ]


conflitos : Test
conflitos =
    describe "conflitos"
        [ test "tabuleiro sem marcas não tem conflito" <|
            \_ ->
                Rack.conflitos Exemplo.puzzle
                    |> Expect.equal []
        , test "linha com mais servidores que a carga" <|
            \_ ->
                Rack.criar 1 3 [ 1 ] [ 1, 1, 1 ] []
                    |> comServidores [ Posicao 0 0, Posicao 0 2 ]
                    |> Rack.conflitos
                    |> Expect.equal [ LinhaExcedida 0 ]
        , test "coluna com mais servidores que a carga" <|
            \_ ->
                Rack.criar 3 1 [ 1, 1, 1 ] [ 1 ] []
                    |> comServidores [ Posicao 0 0, Posicao 2 0 ]
                    |> Rack.conflitos
                    |> Expect.equal [ ColunaExcedida 0 ]
        , test "sensor no canto com servidores demais em volta" <|
            \_ ->
                Rack.criar 2 2 [ 2, 2 ] [ 2, 2 ] [ ( Posicao 0 0, 1 ) ]
                    |> comServidores [ Posicao 0 1, Posicao 1 0 ]
                    |> Rack.conflitos
                    |> Expect.equal [ SensorExcedido (Posicao 0 0) ]
        , test "servidores encostados na horizontal" <|
            \_ ->
                Rack.criar 1 2 [ 2 ] [ 1, 1 ] []
                    |> comServidores [ Posicao 0 0, Posicao 0 1 ]
                    |> Rack.conflitos
                    |> Expect.equal [ ServidoresEncostados (Posicao 0 0) (Posicao 0 1) ]
        , test "servidores encostados na vertical" <|
            \_ ->
                Rack.criar 2 1 [ 1, 1 ] [ 2 ] []
                    |> comServidores [ Posicao 0 0, Posicao 1 0 ]
                    |> Rack.conflitos
                    |> Expect.equal [ ServidoresEncostados (Posicao 0 0) (Posicao 1 0) ]
        , test "servidores na diagonal podem" <|
            \_ ->
                Rack.criar 2 2 [ 1, 1 ] [ 1, 1 ] []
                    |> comServidores [ Posicao 0 0, Posicao 1 1 ]
                    |> Rack.conflitos
                    |> Expect.equal []
        ]


vitoria : Test
vitoria =
    let
        servidoresDaSolucao =
            [ Posicao 0 0, Posicao 0 3, Posicao 1 2, Posicao 1 5, Posicao 2 0, Posicao 2 4 ]
                ++ [ Posicao 3 1, Posicao 4 3, Posicao 4 5, Posicao 5 0, Posicao 5 2 ]
    in
    describe "vitória"
        [ test "a solução do Prolog vence" <|
            \_ ->
                Rack.aplicarSolucao Exemplo.solucao Exemplo.puzzle
                    |> Rack.venceu
                    |> Expect.equal True
        , test "basta marcar os servidores: casa sem marca conta como livre" <|
            \_ ->
                comServidores servidoresDaSolucao Exemplo.puzzle
                    |> Rack.venceu
                    |> Expect.equal True
        , test "faltando um servidor, não vence" <|
            \_ ->
                comServidores (List.drop 1 servidoresDaSolucao) Exemplo.puzzle
                    |> Rack.venceu
                    |> Expect.equal False
        , test "tabuleiro vazio não vence" <|
            \_ ->
                Rack.venceu Exemplo.puzzle
                    |> Expect.equal False
        ]


textos : Test
textos =
    describe "textos"
        [ test "o motivo mostra linha e coluna contadas a partir de 1" <|
            \_ ->
                Rack.descreverMotivo (PorSensor (Posicao 1 2))
                    |> String.contains "linha 2, coluna 3"
                    |> Expect.equal True
        , test "o motivo de linha usa o número da linha" <|
            \_ ->
                Rack.descreverMotivo (PorLinha 0)
                    |> String.contains "linha 1"
                    |> Expect.equal True
        , test "sensores do exemplo" <|
            \_ ->
                List.length (Rack.sensores Exemplo.puzzle)
                    |> Expect.equal 5
        ]


repetir : Int -> (a -> a) -> a -> a
repetir vezes funcao valor =
    if vezes <= 0 then
        valor

    else
        repetir (vezes - 1) funcao (funcao valor)
