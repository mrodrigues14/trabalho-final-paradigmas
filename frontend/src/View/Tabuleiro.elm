module View.Tabuleiro exposing (Config, view)

import Array
import Html exposing (Html, button, div, span, text)
import Html.Attributes exposing (attribute, class, classList, disabled)
import Html.Events exposing (onClick)
import Rack exposing (Casa(..), Conflito(..), Dica, Marca(..), Motivo(..), Posicao, Puzzle)


type alias Config msg =
    { aoClicar : Posicao -> msg
    , selecionada : Maybe Posicao
    , dica : Maybe Dica
    , contradicao : List Posicao
    , resolvido : Bool
    }


type SituacaoCarga
    = Faltando
    | Batendo
    | Excedida


view : Config msg -> Puzzle -> Html msg
view config puzzle =
    let
        emConflito =
            casasEmConflito (Rack.conflitos puzzle) ++ config.contradicao

        cabecalho =
            div [ class "board-corner" ] []
                :: List.map (viewCargaColuna config puzzle) (List.range 0 (puzzle.colunas - 1))

        linha l =
            viewCargaLinha config puzzle l
                :: List.map
                    (\c -> viewCasa config puzzle emConflito { linha = l, coluna = c })
                    (List.range 0 (puzzle.colunas - 1))
    in
    div
        [ class "board"
        , classList [ ( "board--solved", config.resolvido ) ]
        , attribute "style"
            ("--cols: " ++ String.fromInt puzzle.colunas ++ "; --rows: " ++ String.fromInt puzzle.linhas)
        ]
        (cabecalho ++ List.concatMap linha (List.range 0 (puzzle.linhas - 1)))


viewCargaLinha : Config msg -> Puzzle -> Int -> Html msg
viewCargaLinha config puzzle l =
    viewCarga
        (Array.get l puzzle.cargasLinha |> Maybe.withDefault 0)
        (Rack.servidoresNaLinha l puzzle)
        (motivoAponta config (\m -> m == PorLinha l))


viewCargaColuna : Config msg -> Puzzle -> Int -> Html msg
viewCargaColuna config puzzle c =
    viewCarga
        (Array.get c puzzle.cargasColuna |> Maybe.withDefault 0)
        (Rack.servidoresNaColuna c puzzle)
        (motivoAponta config (\m -> m == PorColuna c))


viewCarga : Int -> Int -> Bool -> Html msg
viewCarga carga marcados ehMotivo =
    let
        situacao =
            if marcados > carga then
                Excedida

            else if marcados == carga then
                Batendo

            else
                Faltando
    in
    div
        [ class "count"
        , classList
            [ ( "count--ok", situacao == Batendo )
            , ( "count--over", situacao == Excedida )
            , ( "count--reason", ehMotivo )
            ]
        , attribute "title" (String.fromInt marcados ++ " de " ++ String.fromInt carga ++ " servidores")
        ]
        [ text (String.fromInt carga) ]


viewCasa : Config msg -> Puzzle -> List Posicao -> Posicao -> Html msg
viewCasa config puzzle emConflito posicao =
    let
        casa =
            Rack.casaEm posicao puzzle |> Maybe.withDefault (Aberta SemMarca)

        ehDica =
            Maybe.map .posicao config.dica == Just posicao

        classes =
            [ ( "cell--selected", config.selecionada == Just posicao )
            , ( "cell--conflict", List.member posicao emConflito )
            , ( "cell--hint", ehDica )
            , ( "cell--reason", motivoAponta config (apontaCasa posicao) )
            ]

        rotulo =
            "Linha " ++ String.fromInt (posicao.linha + 1) ++ ", coluna " ++ String.fromInt (posicao.coluna + 1)
    in
    case casa of
        Sensor n ->
            div
                [ class "cell cell--sensor"
                , classList classes
                , attribute "aria-label" (rotulo ++ ": sensor " ++ String.fromInt n)
                ]
                [ span [ class "cell-value" ] [ text (String.fromInt n) ] ]

        Aberta marca ->
            button
                [ class "cell"
                , classList
                    (( "cell--server", marca == Servidor )
                        :: ( "cell--free", marca == Livre )
                        :: classes
                    )
                , attribute "aria-label" (rotulo ++ ": " ++ nomeMarca marca)
                , disabled config.resolvido
                , onClick (config.aoClicar posicao)
                ]
                [ viewMarca marca ]


viewMarca : Marca -> Html msg
viewMarca marca =
    case marca of
        Servidor ->
            span [ class "server-icon" ] []

        Livre ->
            span [ class "free-icon" ] []

        SemMarca ->
            text ""


nomeMarca : Marca -> String
nomeMarca marca =
    case marca of
        Servidor ->
            "servidor"

        Livre ->
            "livre"

        SemMarca ->
            "sem marca"


motivoAponta : Config msg -> (Motivo -> Bool) -> Bool
motivoAponta config teste =
    case config.dica of
        Just { motivo } ->
            teste motivo

        Nothing ->
            False


apontaCasa : Posicao -> Motivo -> Bool
apontaCasa posicao motivo =
    case motivo of
        PorLinha l ->
            posicao.linha == l

        PorColuna c ->
            posicao.coluna == c

        PorSensor p ->
            p == posicao

        PorRefrigeracao p ->
            p == posicao

        Combinado ->
            False


casasEmConflito : List Conflito -> List Posicao
casasEmConflito =
    List.concatMap
        (\conflito ->
            case conflito of
                SensorExcedido p ->
                    [ p ]

                ServidoresEncostados a b ->
                    [ a, b ]

                LinhaExcedida _ ->
                    []

                ColunaExcedida _ ->
                    []
        )
