module View.Painel exposing
    ( Mensagem(..)
    , acoes
    , cronometro
    , dica
    , dificuldade
    , formatarTempo
    , mensagem
    , rotulo
    )

import Html exposing (Html, button, div, p, span, text)
import Html.Attributes exposing (class, classList, disabled)
import Html.Events exposing (onClick)
import Rack exposing (Dica, Dificuldade(..), Marca(..))


rotulo : String -> Html msg
rotulo texto =
    span [ class "panel-label" ] [ text texto ]


dificuldade : { atual : Dificuldade, bloqueado : Bool, aoEscolher : Dificuldade -> msg } -> Html msg
dificuldade { atual, bloqueado, aoEscolher } =
    let
        opcao nivel =
            button
                [ class "difficulty-option"
                , classList [ ( "difficulty-option--active", nivel == atual ) ]
                , disabled bloqueado
                , onClick (aoEscolher nivel)
                ]
                [ text (Rack.dificuldadeTexto nivel) ]
    in
    div [ class "difficulty-picker" ] (List.map opcao [ Facil, Medio, Dificil ])


cronometro : Int -> Html msg
cronometro segundos =
    div [ class "timer" ] [ text ("⏱ " ++ formatarTempo segundos) ]


formatarTempo : Int -> String
formatarTempo segundos =
    let
        doisDigitos n =
            String.padLeft 2 '0' (String.fromInt n)
    in
    doisDigitos (segundos // 60) ++ ":" ++ doisDigitos (modBy 60 segundos)


type Mensagem msg
    = Nenhuma
    | Pensando
    | Info String
    | Sucesso String
    | Erro String msg


mensagem : Mensagem msg -> Html msg
mensagem conteudo =
    div [ class "message-area" ]
        [ case conteudo of
            Nenhuma ->
                text ""

            Pensando ->
                div [ class "message message--loading" ]
                    [ span [ class "spinner" ] []
                    , span [] [ text "O Prolog está pensando..." ]
                    ]

            Info texto ->
                div [ class "message message--info" ] [ text texto ]

            Sucesso texto ->
                div [ class "message message--success" ] [ text texto ]

            Erro texto aoFechar ->
                div [ class "message message--error" ]
                    [ span [] [ text texto ]
                    , button [ class "message-close", onClick aoFechar ] [ text "✕" ]
                    ]
        ]


dica : Maybe Dica -> Html msg
dica talvez =
    case talvez of
        Just { posicao, valor, motivo } ->
            div [ class "hint-panel hint-panel--active" ]
                [ p [ class "hint-title" ]
                    [ text
                        ("Casa ("
                            ++ String.fromInt (posicao.linha + 1)
                            ++ ", "
                            ++ String.fromInt (posicao.coluna + 1)
                            ++ "): "
                            ++ nomeValor valor
                        )
                    ]
                , p [ class "hint-reason" ] [ text (Rack.descreverMotivo motivo) ]
                ]

        Nothing ->
            div [ class "hint-panel" ]
                [ p [ class "hint-reason" ] [ text "Peça uma dica: o Prolog mostra uma casa e a regra que a decide." ] ]


nomeValor : Marca -> String
nomeValor marca =
    case marca of
        Servidor ->
            "servidor"

        Livre ->
            "livre"

        SemMarca ->
            "sem marca"


acoes :
    { aoPedirDica : msg
    , aoMostrarSolucao : msg
    , aoDesfazer : msg
    , podeDesfazer : Bool
    , bloqueado : Bool
    }
    -> Html msg
acoes config =
    div [ class "actions" ]
        [ button
            [ class "action-button action-button--hint"
            , disabled config.bloqueado
            , onClick config.aoPedirDica
            ]
            [ text "Dica" ]
        , button
            [ class "action-button action-button--solve"
            , disabled config.bloqueado
            , onClick config.aoMostrarSolucao
            ]
            [ text "Solução" ]
        , button
            [ class "action-button action-button--reset"
            , disabled (not config.podeDesfazer)
            , onClick config.aoDesfazer
            ]
            [ text "Desfazer" ]
        ]
