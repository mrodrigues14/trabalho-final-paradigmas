module ApiTest exposing (suite)

import Api exposing (Verificacao(..))
import Array
import Exemplo
import Expect
import Json.Decode as Decode
import Json.Encode as Encode
import Rack exposing (Casa(..), Marca(..), Motivo(..), Posicao)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Api"
        [ puzzle
        , marcas
        , dica
        , verificacao
        ]


puzzle : Test
puzzle =
    describe "puzzle"
        [ test "decodifica o puzzle do contrato da API" <|
            \_ ->
                """
                { "rows": 6, "cols": 6,
                  "rowCounts": [2, 1, 2, 1, 2, 1],
                  "colCounts": [1, 2, 1, 2, 1, 2],
                  "sensors": [[0, 3, 2], [4, 1, 3]] }
                """
                    |> Decode.decodeString Api.puzzleDecoder
                    |> Result.map
                        (\p ->
                            ( ( p.linhas, Array.toList p.cargasLinha ), Rack.sensores p, Rack.casaEm (Posicao 0 0) p )
                        )
                    |> Expect.equal
                        (Ok
                            ( ( 6, [ 2, 1, 2, 1, 2, 1 ] )
                            , [ ( Posicao 0 3, 2 ), ( Posicao 4 1, 3 ) ]
                            , Just (Aberta SemMarca)
                            )
                        )
        , test "o puzzle enviado volta igual ao ser lido" <|
            \_ ->
                Api.codificarPedido Exemplo.puzzle
                    |> Decode.decodeValue (Decode.field "puzzle" Api.puzzleDecoder)
                    |> Expect.equal (Ok Exemplo.puzzle)
        , test "a solução vem no campo grid" <|
            \_ ->
                Decode.decodeString Api.solucaoDecoder """{"grid": [[1, 0], [0, 1]]}"""
                    |> Expect.equal (Ok [ [ 1, 0 ], [ 0, 1 ] ])
        ]


marcas : Test
marcas =
    describe "marcas"
        [ test "servidor é 1, livre é 2, sem marca e sensor são 0" <|
            \_ ->
                Exemplo.puzzle
                    |> Rack.marcar (Posicao 1 3) Servidor
                    |> Rack.marcar (Posicao 1 5) Livre
                    |> Api.codificarPedido
                    |> Decode.decodeValue (Decode.field "marks" (Decode.index 1 (Decode.list Decode.int)))
                    |> Expect.equal (Ok [ 0, 0, 0, 1, 0, 2 ])
        ]


dica : Test
dica =
    let
        decodificar razao =
            Encode.object
                [ ( "row", Encode.int 2 )
                , ( "col", Encode.int 3 )
                , ( "value", Encode.int 1 )
                , ( "reason", razao )
                ]
                |> Decode.decodeValue Api.dicaDecoder
                |> Result.map .motivo

        camposInteiros campos =
            List.map (Tuple.mapSecond Encode.int) campos

        semTipo campos =
            Encode.object (camposInteiros campos)

        comTipo tipo campos =
            Encode.object (( "kind", Encode.string tipo ) :: camposInteiros campos)
    in
    describe "dica"
        [ test "posição e valor da dica" <|
            \_ ->
                """{"row": 2, "col": 3, "value": 0, "reason": {"kind": "combined"}}"""
                    |> Decode.decodeString Api.dicaDecoder
                    |> Result.map (\d -> ( d.posicao, d.valor ))
                    |> Expect.equal (Ok ( Posicao 2 3, Livre ))
        , test "motivo por linha" <|
            \_ ->
                decodificar (comTipo "row" [ ( "index", 4 ) ])
                    |> Expect.equal (Ok (PorLinha 4))
        , test "motivo por coluna" <|
            \_ ->
                decodificar (comTipo "col" [ ( "index", 1 ) ])
                    |> Expect.equal (Ok (PorColuna 1))
        , test "motivo por sensor" <|
            \_ ->
                decodificar (comTipo "sensor" [ ( "row", 1 ), ( "col", 2 ) ])
                    |> Expect.equal (Ok (PorSensor (Posicao 1 2)))
        , test "motivo por refrigeração" <|
            \_ ->
                decodificar (comTipo "cooling" [ ( "row", 2 ), ( "col", 4 ) ])
                    |> Expect.equal (Ok (PorRefrigeracao (Posicao 2 4)))
        , test "motivo combinado" <|
            \_ ->
                decodificar (comTipo "combined" [])
                    |> Expect.equal (Ok Combinado)
        , test "motivo desconhecido é erro" <|
            \_ ->
                decodificar (comTipo "magia" [])
                    |> Expect.err
        , test "motivo sem kind é erro" <|
            \_ ->
                decodificar (semTipo [ ( "index", 1 ) ])
                    |> Expect.err
        , test "valor diferente de 0 e 1 é erro" <|
            \_ ->
                """{"row": 0, "col": 0, "value": 2, "reason": {"kind": "combined"}}"""
                    |> Decode.decodeString Api.dicaDecoder
                    |> Expect.err
        ]


verificacao : Test
verificacao =
    describe "verificação"
        [ test "sem contradição" <|
            \_ ->
                Decode.decodeString Api.verificacaoDecoder """{"status": "ok"}"""
                    |> Expect.equal (Ok SemContradicao)
        , test "contradição com as casas culpadas" <|
            \_ ->
                Decode.decodeString Api.verificacaoDecoder """{"status": "contradiction", "cells": [[0, 1], [3, 2]]}"""
                    |> Expect.equal (Ok (Contradicao [ Posicao 0 1, Posicao 3 2 ]))
        , test "status desconhecido é erro" <|
            \_ ->
                Decode.decodeString Api.verificacaoDecoder """{"status": "talvez"}"""
                    |> Expect.err
        ]
