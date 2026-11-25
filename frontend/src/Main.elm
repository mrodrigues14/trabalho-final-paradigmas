module Main exposing (main)

import Api exposing (Verificacao(..))
import Browser
import Browser.Events
import Html exposing (Html, aside, button, div, footer, h1, header, input, label, main_, span, text)
import Html.Attributes exposing (attribute, checked, class, type_, value)
import Html.Events exposing (onCheck, onClick)
import Json.Decode as Decode exposing (Decoder)
import Rack exposing (Dica, Dificuldade(..), Marca(..), Posicao, Puzzle)
import Time
import View.Painel as Painel
import View.Tabuleiro as Tabuleiro


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


type alias Flags =
    { darkTheme : Bool
    }


type alias Model =
    { estado : Estado
    , dificuldade : Dificuldade
    , temaEscuro : Bool
    }


type Estado
    = Carregando
    | Jogando Jogo
    | Vitoria Jogo
    | Falha String


type alias Jogo =
    { puzzle : Puzzle
    , selecionada : Maybe Posicao
    , dica : Maybe Dica
    , segundos : Int
    , historico : List Puzzle
    , pensando : Bool
    , aviso : Maybe String
    , revelada : Bool
    , verificacao : Maybe Verificacao
    }


novoJogo : Puzzle -> Jogo
novoJogo puzzle =
    { puzzle = puzzle
    , selecionada = Nothing
    , dica = Nothing
    , segundos = 0
    , historico = []
    , pensando = False
    , aviso = Nothing
    , revelada = False
    , verificacao = Nothing
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { estado = Carregando, dificuldade = Facil, temaEscuro = flags.darkTheme }
    , Api.gerar Facil PuzzleChegou
    )


type Msg
    = NovoJogo Dificuldade
    | PuzzleChegou (Result String Puzzle)
    | Clicou Posicao
    | Tecla Teclado
    | PediuDica
    | DicaChegou (Result String Dica)
    | PediuSolucao
    | SolucaoChegou (Result String (List (List Int)))
    | PediuVerificacao
    | VerificacaoChegou (Result String Verificacao)
    | Desfazer
    | Tique
    | TrocouTema Bool
    | FechouAviso


type Teclado
    = Mover Int Int
    | Marcar Marca
    | TeclaDica
    | TeclaVerificar
    | TeclaDesfazer


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NovoJogo dificuldade ->
            ( { model | estado = Carregando, dificuldade = dificuldade }
            , Api.gerar dificuldade PuzzleChegou
            )

        PuzzleChegou (Ok puzzle) ->
            ( { model | estado = Jogando (novoJogo puzzle) }, Cmd.none )

        PuzzleChegou (Err erro) ->
            ( { model | estado = Falha erro }, Cmd.none )

        Clicou posicao ->
            noJogo model
                (\jogo ->
                    ( mudarPuzzle (Rack.alternar posicao) { jogo | selecionada = Just posicao }
                    , Cmd.none
                    )
                )

        Tecla (Mover dLinha dColuna) ->
            noJogo model (\jogo -> ( mover dLinha dColuna jogo, Cmd.none ))

        Tecla (Marcar marca) ->
            noJogo model
                (\jogo ->
                    case jogo.selecionada of
                        Just posicao ->
                            ( mudarPuzzle (Rack.marcar posicao marca) jogo, Cmd.none )

                        Nothing ->
                            ( jogo, Cmd.none )
                )

        Tecla TeclaDica ->
            update PediuDica model

        Tecla TeclaVerificar ->
            update PediuVerificacao model

        Tecla TeclaDesfazer ->
            update Desfazer model

        PediuDica ->
            noJogo model
                (\jogo ->
                    if jogo.pensando || jogo.revelada then
                        ( jogo, Cmd.none )

                    else
                        ( { jogo | pensando = True, aviso = Nothing }, Api.pedirDica jogo.puzzle DicaChegou )
                )

        DicaChegou (Ok dica) ->
            noJogo model
                (\jogo ->
                    let
                        marcado =
                            mudarPuzzle (Rack.aplicarDica dica) jogo
                    in
                    ( { marcado | dica = Just dica, selecionada = Just dica.posicao, pensando = False }
                    , Cmd.none
                    )
                )

        DicaChegou (Err erro) ->
            noJogo model (\jogo -> ( avisar erro jogo, Cmd.none ))

        PediuSolucao ->
            noJogo model
                (\jogo ->
                    if jogo.pensando then
                        ( jogo, Cmd.none )

                    else
                        ( { jogo | pensando = True, aviso = Nothing }, Api.resolver jogo.puzzle SolucaoChegou )
                )

        SolucaoChegou (Ok grade) ->
            noJogo model
                (\jogo ->
                    ( { jogo
                        | puzzle = Rack.aplicarSolucao grade jogo.puzzle
                        , historico = jogo.puzzle :: jogo.historico
                        , dica = Nothing
                        , pensando = False
                        , revelada = True
                        , verificacao = Nothing
                      }
                    , Cmd.none
                    )
                )

        SolucaoChegou (Err erro) ->
            noJogo model (\jogo -> ( avisar erro jogo, Cmd.none ))

        PediuVerificacao ->
            noJogo model
                (\jogo ->
                    if jogo.pensando || jogo.revelada then
                        ( jogo, Cmd.none )

                    else
                        ( { jogo | pensando = True, aviso = Nothing }, Api.verificar jogo.puzzle VerificacaoChegou )
                )

        VerificacaoChegou (Ok verificacao) ->
            noJogo model (\jogo -> ( { jogo | verificacao = Just verificacao, pensando = False }, Cmd.none ))

        VerificacaoChegou (Err erro) ->
            noJogo model (\jogo -> ( avisar erro jogo, Cmd.none ))

        Desfazer ->
            noJogo model
                (\jogo ->
                    case jogo.historico of
                        anterior :: resto ->
                            ( { jogo | puzzle = anterior, historico = resto, dica = Nothing, verificacao = Nothing }, Cmd.none )

                        [] ->
                            ( jogo, Cmd.none )
                )

        Tique ->
            noJogo model (\jogo -> ( { jogo | segundos = jogo.segundos + 1 }, Cmd.none ))

        TrocouTema escuro ->
            ( { model | temaEscuro = escuro }, Cmd.none )

        FechouAviso ->
            noJogo model (\jogo -> ( { jogo | aviso = Nothing }, Cmd.none ))


noJogo : Model -> (Jogo -> ( Jogo, Cmd Msg )) -> ( Model, Cmd Msg )
noJogo model mudar =
    case model.estado of
        Jogando jogo ->
            let
                ( novo, cmd ) =
                    mudar jogo

                estado =
                    if not novo.revelada && Rack.venceu novo.puzzle then
                        Vitoria { novo | selecionada = Nothing }

                    else
                        Jogando novo
            in
            ( { model | estado = estado }, cmd )

        _ ->
            ( model, Cmd.none )


mudarPuzzle : (Puzzle -> Puzzle) -> Jogo -> Jogo
mudarPuzzle mudar jogo =
    let
        novo =
            mudar jogo.puzzle
    in
    if novo == jogo.puzzle then
        jogo

    else
        { jogo
            | puzzle = novo
            , historico = jogo.puzzle :: jogo.historico
            , dica = Nothing
            , aviso = Nothing
            , verificacao = Nothing
        }


mover : Int -> Int -> Jogo -> Jogo
mover dLinha dColuna jogo =
    let
        { linhas, colunas } =
            jogo.puzzle

        destino =
            case jogo.selecionada of
                Just { linha, coluna } ->
                    { linha = modBy linhas (linha + dLinha), coluna = modBy colunas (coluna + dColuna) }

                Nothing ->
                    { linha = 0, coluna = 0 }
    in
    { jogo | selecionada = Just destino }


avisar : String -> Jogo -> Jogo
avisar erro jogo =
    { jogo | pensando = False, aviso = Just erro }


subscriptions : Model -> Sub Msg
subscriptions model =
    case model.estado of
        Jogando jogo ->
            Sub.batch
                [ Browser.Events.onKeyDown (Decode.map Tecla decoderTecla)
                , if jogo.revelada then
                    Sub.none

                  else
                    Time.every 1000 (\_ -> Tique)
                ]

        _ ->
            Sub.none


decoderTecla : Decoder Teclado
decoderTecla =
    Decode.field "key" Decode.string
        |> Decode.andThen (String.toLower >> teclaParaMsg)


teclaParaMsg : String -> Decoder Teclado
teclaParaMsg tecla =
    case tecla of
        "arrowup" ->
            Decode.succeed (Mover -1 0)

        "arrowdown" ->
            Decode.succeed (Mover 1 0)

        "arrowleft" ->
            Decode.succeed (Mover 0 -1)

        "arrowright" ->
            Decode.succeed (Mover 0 1)

        "s" ->
            Decode.succeed (Marcar Servidor)

        "l" ->
            Decode.succeed (Marcar Livre)

        "backspace" ->
            Decode.succeed (Marcar SemMarca)

        "delete" ->
            Decode.succeed (Marcar SemMarca)

        "h" ->
            Decode.succeed TeclaDica

        "v" ->
            Decode.succeed TeclaVerificar

        "u" ->
            Decode.succeed TeclaDesfazer

        _ ->
            Decode.fail "tecla ignorada"


view : Model -> Html Msg
view model =
    div [ class "app" ]
        [ header [ class "app-header" ]
            [ div [ class "app-container app-header-content" ]
                [ h1 [ class "app-title" ] [ text "Rack" ]
                , span [ class "app-subtitle" ] [ text "Prolog + Elm" ]
                , viewTema model.temaEscuro
                ]
            ]
        , main_ [ class "app-main" ]
            [ div [ class "app-container game" ]
                [ viewCentro model
                , aside [ class "side-panel" ] (viewPainel model)
                ]
            ]
        , footer [ class "app-footer" ]
            [ text "Teclado: "
            , kbd "setas"
            , text " movem, "
            , kbd "S"
            , text " servidor, "
            , kbd "L"
            , text " livre, "
            , kbd "⌫"
            , text " limpa, "
            , kbd "H"
            , text " dica, "
            , kbd "V"
            , text " verifica, "
            , kbd "U"
            , text " desfaz."
            ]
        ]


viewCentro : Model -> Html Msg
viewCentro model =
    case model.estado of
        Carregando ->
            div [ class "board-placeholder" ]
                [ span [ class "spinner spinner--large" ] []
                , span [] [ text "O Prolog está montando o datacenter..." ]
                ]

        Falha erro ->
            div [ class "board-placeholder board-placeholder--error" ]
                [ span [ class "placeholder-title" ] [ text "Não deu para carregar o puzzle" ]
                , span [] [ text erro ]
                , button [ class "action-button action-button--hint", onClick (NovoJogo model.dificuldade) ]
                    [ text "Tentar de novo" ]
                ]

        Jogando jogo ->
            Tabuleiro.view
                { aoClicar = Clicou
                , selecionada = jogo.selecionada
                , dica = jogo.dica
                , contradicao = casasContraditorias jogo.verificacao
                , resolvido = False
                }
                jogo.puzzle

        Vitoria jogo ->
            Tabuleiro.view
                { aoClicar = Clicou
                , selecionada = Nothing
                , dica = Nothing
                , contradicao = []
                , resolvido = True
                }
                jogo.puzzle


viewPainel : Model -> List (Html Msg)
viewPainel model =
    let
        seletor bloqueado =
            Painel.dificuldade { atual = model.dificuldade, bloqueado = bloqueado, aoEscolher = NovoJogo }
    in
    case model.estado of
        Carregando ->
            [ Painel.rotulo "Novo jogo", seletor True, Painel.mensagem Painel.Pensando ]

        Falha _ ->
            [ Painel.rotulo "Novo jogo", seletor False ]

        Jogando jogo ->
            [ Painel.rotulo "Novo jogo"
            , seletor jogo.pensando
            , Painel.cronometro jogo.segundos
            , Painel.mensagem
                (case ( jogo.aviso, jogo.pensando, jogo.revelada ) of
                    ( Just erro, _, _ ) ->
                        Painel.Erro erro FechouAviso

                    ( Nothing, True, _ ) ->
                        Painel.Pensando

                    ( Nothing, False, True ) ->
                        Painel.Info "Esta é a solução do Prolog."

                    ( Nothing, False, False ) ->
                        mensagemVerificacao jogo.verificacao
                )
            , Painel.rotulo "Dica"
            , Painel.dica jogo.dica
            , Painel.rotulo "Ajuda"
            , Painel.acoes
                { aoPedirDica = PediuDica
                , aoVerificar = PediuVerificacao
                , aoMostrarSolucao = PediuSolucao
                , aoDesfazer = Desfazer
                , podeDesfazer = not (List.isEmpty jogo.historico)
                , bloqueado = jogo.pensando || jogo.revelada
                }
            ]

        Vitoria jogo ->
            [ Painel.rotulo "Novo jogo"
            , seletor False
            , Painel.cronometro jogo.segundos
            , Painel.mensagem
                (Painel.Sucesso
                    ("Datacenter montado em " ++ Painel.formatarTempo jogo.segundos ++ "!")
                )
            , button [ class "action-button action-button--hint", onClick (NovoJogo model.dificuldade) ]
                [ text "Jogar de novo" ]
            ]


{-| As casas que o `/api/check` apontou ficam destacadas como conflito até
o jogador mexer no tabuleiro.
-}
casasContraditorias : Maybe Verificacao -> List Posicao
casasContraditorias verificacao =
    case verificacao of
        Just (Contradicao casas) ->
            casas

        _ ->
            []


mensagemVerificacao : Maybe Verificacao -> Painel.Mensagem Msg
mensagemVerificacao verificacao =
    case verificacao of
        Just SemContradicao ->
            Painel.Sucesso "Tudo certo até aqui."

        Just (Contradicao [ _ ]) ->
            Painel.Info "1 casa marcada não bate com a solução."

        Just (Contradicao casas) ->
            Painel.Info (String.fromInt (List.length casas) ++ " casas marcadas não batem com a solução.")

        Nothing ->
            Painel.Nenhuma


viewTema : Bool -> Html Msg
viewTema escuro =
    label [ class "theme-toggle", attribute "aria-label" "Alternar tema claro/escuro" ]
        [ input
            [ type_ "checkbox"
            , class "theme-controller"
            , value "dark"
            , checked escuro
            , onCheck TrocouTema
            ]
            []
        , span [ class "swap-off" ] [ text "☀" ]
        , span [ class "swap-on" ] [ text "☾" ]
        ]


kbd : String -> Html msg
kbd tecla =
    Html.node "kbd" [] [ text tecla ]
