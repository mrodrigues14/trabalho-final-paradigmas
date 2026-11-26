module Api exposing
    ( Verificacao(..)
    , codificarPedido
    , dicaDecoder
    , gerar
    , pedirDica
    , puzzleDecoder
    , resolver
    , solucaoDecoder
    , verificacaoDecoder
    , verificar
    )

{-| Comunicação com o backend do Rack (FastAPI + Prolog).

O formato do JSON segue o contrato da API (RELATORIO.md, seção 7). Este módulo
só traduz entre esse formato e os tipos do `Rack`; nenhuma regra do jogo
mora aqui.

Toda resposta chega como `Result String a`: a mensagem de erro já vem pronta
para a tela, inclusive o `detail` dos erros 422 do backend.

-}

import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Rack exposing (Casa(..), Dica, Dificuldade(..), Marca(..), Motivo(..), Posicao, Puzzle)


{-| Resposta de `/api/check`: ou as marcas ainda levam a uma solução, ou
estas casas marcadas tornam o puzzle impossível.
-}
type Verificacao
    = SemContradicao
    | Contradicao (List Posicao)



-- REQUISIÇÕES


gerar : Dificuldade -> (Result String Puzzle -> msg) -> Cmd msg
gerar dificuldade aoResponder =
    Http.post
        { url = "/api/generate"
        , body = Http.jsonBody (Encode.object [ ( "difficulty", Encode.string (dificuldadeParaApi dificuldade) ) ])
        , expect = esperarJson aoResponder (Decode.field "puzzle" puzzleDecoder)
        }


resolver : Puzzle -> (Result String (List (List Int)) -> msg) -> Cmd msg
resolver =
    postarPuzzle "/api/solve" solucaoDecoder


pedirDica : Puzzle -> (Result String Dica -> msg) -> Cmd msg
pedirDica =
    postarPuzzle "/api/hint" dicaDecoder


verificar : Puzzle -> (Result String Verificacao -> msg) -> Cmd msg
verificar =
    postarPuzzle "/api/check" verificacaoDecoder


{-| As três rotas que recebem o tabuleiro têm o mesmo corpo; só mudam a URL
e o formato da resposta.
-}
postarPuzzle : String -> Decoder a -> Puzzle -> (Result String a -> msg) -> Cmd msg
postarPuzzle url decoder puzzle aoResponder =
    Http.post
        { url = url
        , body = Http.jsonBody (codificarPedido puzzle)
        , expect = esperarJson aoResponder decoder
        }


dificuldadeParaApi : Dificuldade -> String
dificuldadeParaApi dificuldade =
    case dificuldade of
        Facil ->
            "easy"

        Medio ->
            "medium"

        Dificil ->
            "hard"



-- ENVIO


{-| `{"puzzle": {...}, "marks": [[...]]}`
-}
codificarPedido : Puzzle -> Encode.Value
codificarPedido puzzle =
    Encode.object
        [ ( "puzzle", codificarPuzzle puzzle )
        , ( "marks", Encode.array (Encode.array (marcaParaApi >> Encode.int)) puzzle.casas )
        ]


codificarPuzzle : Puzzle -> Encode.Value
codificarPuzzle puzzle =
    Encode.object
        [ ( "rows", Encode.int puzzle.linhas )
        , ( "cols", Encode.int puzzle.colunas )
        , ( "rowCounts", Encode.array Encode.int puzzle.cargasLinha )
        , ( "colCounts", Encode.array Encode.int puzzle.cargasColuna )
        , ( "sensors", Encode.list codificarSensor (Rack.sensores puzzle) )
        ]


codificarSensor : ( Posicao, Int ) -> Encode.Value
codificarSensor ( { linha, coluna }, numero ) =
    Encode.list Encode.int [ linha, coluna, numero ]


{-| 0 = sem marca, 1 = servidor, 2 = livre. A casa de sensor vai como 0,
como pede o contrato.
-}
marcaParaApi : Casa -> Int
marcaParaApi casa =
    case casa of
        Sensor _ ->
            0

        Aberta SemMarca ->
            0

        Aberta Servidor ->
            1

        Aberta Livre ->
            2



-- RECEBIMENTO


puzzleDecoder : Decoder Puzzle
puzzleDecoder =
    Decode.map5 Rack.criar
        (Decode.field "rows" Decode.int)
        (Decode.field "cols" Decode.int)
        (Decode.field "rowCounts" (Decode.list Decode.int))
        (Decode.field "colCounts" (Decode.list Decode.int))
        (Decode.field "sensors" (Decode.list sensorDecoder))


{-| Um sensor é `[linha, coluna, número]`.
-}
sensorDecoder : Decoder ( Posicao, Int )
sensorDecoder =
    Decode.map2 Tuple.pair posicaoEmListaDecoder (Decode.index 2 Decode.int)


{-| Os dois primeiros elementos de `[linha, coluna, ...]`.
-}
posicaoEmListaDecoder : Decoder Posicao
posicaoEmListaDecoder =
    Decode.map2 Posicao (Decode.index 0 Decode.int) (Decode.index 1 Decode.int)


{-| `{"row": 2, "col": 3}`, dentro de um objeto maior.
-}
posicaoEmCamposDecoder : Decoder Posicao
posicaoEmCamposDecoder =
    Decode.map2 Posicao (Decode.field "row" Decode.int) (Decode.field "col" Decode.int)


solucaoDecoder : Decoder (List (List Int))
solucaoDecoder =
    Decode.field "grid" (Decode.list (Decode.list Decode.int))


dicaDecoder : Decoder Dica
dicaDecoder =
    Decode.map3 Dica
        posicaoEmCamposDecoder
        (Decode.field "value" valorDecoder)
        (Decode.field "reason" motivoDecoder)


{-| Na dica, 1 é servidor e 0 é livre. Qualquer outro número é erro do
servidor, e não uma marca nova.
-}
valorDecoder : Decoder Marca
valorDecoder =
    Decode.int
        |> Decode.andThen
            (\valor ->
                case valor of
                    1 ->
                        Decode.succeed Servidor

                    0 ->
                        Decode.succeed Livre

                    _ ->
                        Decode.fail ("Valor de dica inválido: " ++ String.fromInt valor)
            )


{-| O campo `kind` diz quais outros campos o motivo tem. Lemos ele primeiro
e escolhemos o decoder do resto com `Decode.andThen`.
-}
motivoDecoder : Decoder Motivo
motivoDecoder =
    Decode.field "kind" Decode.string
        |> Decode.andThen motivoPorTipo


motivoPorTipo : String -> Decoder Motivo
motivoPorTipo tipo =
    case tipo of
        "row" ->
            Decode.map PorLinha (Decode.field "index" Decode.int)

        "col" ->
            Decode.map PorColuna (Decode.field "index" Decode.int)

        "sensor" ->
            Decode.map PorSensor posicaoEmCamposDecoder

        "cooling" ->
            Decode.map PorRefrigeracao posicaoEmCamposDecoder

        "combined" ->
            Decode.succeed Combinado

        _ ->
            Decode.fail ("Motivo de dica desconhecido: " ++ tipo)


verificacaoDecoder : Decoder Verificacao
verificacaoDecoder =
    Decode.field "status" Decode.string
        |> Decode.andThen
            (\status ->
                case status of
                    "ok" ->
                        Decode.succeed SemContradicao

                    "contradiction" ->
                        Decode.map Contradicao (Decode.field "cells" (Decode.list posicaoEmListaDecoder))

                    _ ->
                        Decode.fail ("Status de verificação desconhecido: " ++ status)
            )



-- ERROS
--
-- Adaptado do Api.elm do projeto-modelo do professor: o `Http.expectJson`
-- padrão descarta o corpo das respostas de erro, e o nosso backend manda
-- a explicação em `{"detail": "..."}`.


esperarJson : (Result String a -> msg) -> Decoder a -> Http.Expect msg
esperarJson aoResponder decoder =
    Http.expectStringResponse aoResponder <|
        \resposta ->
            case resposta of
                Http.GoodStatus_ _ corpo ->
                    Decode.decodeString decoder corpo
                        |> Result.mapError (\_ -> "Resposta inesperada do servidor.")

                Http.BadStatus_ metadados corpo ->
                    Err (mensagemDeErro metadados.statusCode corpo)

                Http.BadUrl_ url ->
                    Err ("URL inválida: " ++ url)

                Http.Timeout_ ->
                    Err "O servidor demorou demais para responder."

                Http.NetworkError_ ->
                    Err "Não foi possível falar com o servidor. O backend está rodando?"


mensagemDeErro : Int -> String -> String
mensagemDeErro status corpo =
    case Decode.decodeString (Decode.field "detail" Decode.string) corpo of
        Ok detalhe ->
            detalhe

        Err _ ->
            "Erro no servidor (código " ++ String.fromInt status ++ ")."
