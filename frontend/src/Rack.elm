module Rack exposing
    ( Casa(..)
    , Conflito(..)
    , Dica
    , Dificuldade(..)
    , Marca(..)
    , Motivo(..)
    , Posicao
    , Puzzle
    , alternar
    , aplicarDica
    , aplicarSolucao
    , casaEm
    , conflitos
    , criar
    , descreverMotivo
    , dificuldadeTexto
    , marcar
    , sensores
    , servidoresNaColuna
    , servidoresNaLinha
    , venceu
    )

{-| Regras do Rack do lado do Elm.

Este módulo é puro: não conhece HTML nem HTTP. A interface (Main) e a
comunicação com o backend (Api) dependem dele, e não o contrário.

A validação aqui é só a instantânea, a cada clique: contar servidores e olhar
vizinhos. Gerar puzzles, garantir solução única e explicar dicas exige busca,
e isso fica no Prolog.

-}

import Array exposing (Array)



-- TIPOS


type alias Posicao =
    { linha : Int, coluna : Int }


type Marca
    = SemMarca
    | Servidor
    | Livre


{-| Um sensor não é uma casa aberta com um `Bool` "tem sensor": é outro
construtor. Assim não existe, nem por engano, um sensor marcado como
servidor. Toda função que recebe uma `Casa` é obrigada pelo compilador a
decidir o que fazer com o sensor.
-}
type Casa
    = Sensor Int
    | Aberta Marca


type alias Puzzle =
    { linhas : Int
    , colunas : Int
    , cargasLinha : Array Int
    , cargasColuna : Array Int
    , casas : Array (Array Casa)
    }


type Conflito
    = LinhaExcedida Int
    | ColunaExcedida Int
    | SensorExcedido Posicao
    | ServidoresEncostados Posicao Posicao


{-| A regra que forçou a casa de uma dica, como o Prolog explicou.
-}
type Motivo
    = PorLinha Int
    | PorColuna Int
    | PorSensor Posicao
    | PorRefrigeracao Posicao
    | Combinado


type alias Dica =
    { posicao : Posicao, valor : Marca, motivo : Motivo }


type Dificuldade
    = Facil
    | Medio
    | Dificil



-- CONSTRUÇÃO


{-| Monta um puzzle sem marcas. Os sensores vêm como (posição, número).
-}
criar : Int -> Int -> List Int -> List Int -> List ( Posicao, Int ) -> Puzzle
criar linhas colunas cargasLinha cargasColuna listaDeSensores =
    { linhas = linhas
    , colunas = colunas
    , cargasLinha = Array.fromList cargasLinha
    , cargasColuna = Array.fromList cargasColuna
    , casas =
        Array.initialize linhas
            (\linha ->
                Array.initialize colunas
                    (\coluna -> casaInicial listaDeSensores (Posicao linha coluna))
            )
    }


casaInicial : List ( Posicao, Int ) -> Posicao -> Casa
casaInicial listaDeSensores posicao =
    case List.filter (\( lugar, _ ) -> lugar == posicao) listaDeSensores of
        ( _, numero ) :: _ ->
            Sensor numero

        [] ->
            Aberta SemMarca



-- CONSULTAS


{-| `Nothing` fora da grade. As outras funções contam com isso: uma vizinha
fora da grade simplesmente não é servidor, sem teste de limite à parte.
-}
casaEm : Posicao -> Puzzle -> Maybe Casa
casaEm posicao puzzle =
    Array.get posicao.linha puzzle.casas
        |> Maybe.andThen (Array.get posicao.coluna)


sensores : Puzzle -> List ( Posicao, Int )
sensores puzzle =
    List.filterMap
        (\posicao ->
            case casaEm posicao puzzle of
                Just (Sensor numero) ->
                    Just ( posicao, numero )

                _ ->
                    Nothing
        )
        (posicoes puzzle)


servidoresNaLinha : Int -> Puzzle -> Int
servidoresNaLinha linha puzzle =
    List.range 0 (puzzle.colunas - 1)
        |> List.map (Posicao linha)
        |> contarServidores puzzle


servidoresNaColuna : Int -> Puzzle -> Int
servidoresNaColuna coluna puzzle =
    List.range 0 (puzzle.linhas - 1)
        |> List.map (\linha -> Posicao linha coluna)
        |> contarServidores puzzle


servidoresEmVolta : Posicao -> Puzzle -> Int
servidoresEmVolta posicao puzzle =
    contarServidores puzzle (vizinhas8 posicao)


posicoes : Puzzle -> List Posicao
posicoes puzzle =
    List.range 0 (puzzle.linhas - 1)
        |> List.concatMap
            (\linha -> List.map (Posicao linha) (List.range 0 (puzzle.colunas - 1)))


vizinhas8 : Posicao -> List Posicao
vizinhas8 { linha, coluna } =
    List.range -1 1
        |> List.concatMap (\dl -> List.map (\dc -> ( dl, dc )) (List.range -1 1))
        |> List.filter (\deslocamento -> deslocamento /= ( 0, 0 ))
        |> List.map (\( dl, dc ) -> Posicao (linha + dl) (coluna + dc))


ehServidor : Puzzle -> Posicao -> Bool
ehServidor puzzle posicao =
    casaEm posicao puzzle == Just (Aberta Servidor)


contarServidores : Puzzle -> List Posicao -> Int
contarServidores puzzle =
    List.filter (ehServidor puzzle) >> List.length



-- ALTERAÇÕES


{-| Põe uma marca numa casa aberta. Um sensor nunca muda.
-}
marcar : Posicao -> Marca -> Puzzle -> Puzzle
marcar posicao marca =
    atualizarCasa posicao (mudarMarca (always marca))


{-| Clique na casa: sem marca → servidor → livre → sem marca.
-}
alternar : Posicao -> Puzzle -> Puzzle
alternar posicao =
    atualizarCasa posicao (mudarMarca proximaMarca)


aplicarDica : Dica -> Puzzle -> Puzzle
aplicarDica dica =
    marcar dica.posicao dica.valor


{-| Marca todas as casas abertas com a solução do Prolog (1 = servidor,
0 = livre). As casas de sensor seguem intactas, porque `marcar` não as muda.
-}
aplicarSolucao : List (List Int) -> Puzzle -> Puzzle
aplicarSolucao grade puzzle =
    grade
        |> List.indexedMap
            (\linha valores ->
                List.indexedMap (\coluna valor -> ( Posicao linha coluna, valor )) valores
            )
        |> List.concat
        |> List.foldl (\( posicao, valor ) -> marcar posicao (marcaDoValor valor)) puzzle


marcaDoValor : Int -> Marca
marcaDoValor valor =
    if valor == 1 then
        Servidor

    else
        Livre


proximaMarca : Marca -> Marca
proximaMarca marca =
    case marca of
        SemMarca ->
            Servidor

        Servidor ->
            Livre

        Livre ->
            SemMarca


mudarMarca : (Marca -> Marca) -> Casa -> Casa
mudarMarca mudar casa =
    case casa of
        Sensor _ ->
            casa

        Aberta marca ->
            Aberta (mudar marca)


atualizarCasa : Posicao -> (Casa -> Casa) -> Puzzle -> Puzzle
atualizarCasa posicao mudar puzzle =
    { puzzle | casas = mudarEm posicao.linha (mudarEm posicao.coluna mudar) puzzle.casas }


{-| Aplica `mudar` no elemento do índice. Fora do Array, nada muda.
-}
mudarEm : Int -> (a -> a) -> Array a -> Array a
mudarEm indice mudar array =
    case Array.get indice array of
        Just valor ->
            Array.set indice (mudar valor) array

        Nothing ->
            array



-- REGRAS


{-| Tudo o que já está errado no tabuleiro, por mais que o jogador ainda
marque. Faltar servidor não é conflito: o jogador só não terminou.
-}
conflitos : Puzzle -> List Conflito
conflitos puzzle =
    List.concat
        [ List.map LinhaExcedida (indicesExcedidos puzzle.cargasLinha (\i -> servidoresNaLinha i puzzle))
        , List.map ColunaExcedida (indicesExcedidos puzzle.cargasColuna (\j -> servidoresNaColuna j puzzle))
        , sensoresExcedidos puzzle
        , servidoresEncostados puzzle
        ]


indicesExcedidos : Array Int -> (Int -> Int) -> List Int
indicesExcedidos cargas contar =
    Array.toIndexedList cargas
        |> List.filter (\( indice, carga ) -> contar indice > carga)
        |> List.map Tuple.first


sensoresExcedidos : Puzzle -> List Conflito
sensoresExcedidos puzzle =
    sensores puzzle
        |> List.filter (\( posicao, numero ) -> servidoresEmVolta posicao puzzle > numero)
        |> List.map (Tuple.first >> SensorExcedido)


{-| Cada par aparece uma vez só, porque olhamos só para a direita e para
baixo de cada servidor.
-}
servidoresEncostados : Puzzle -> List Conflito
servidoresEncostados puzzle =
    posicoes puzzle
        |> List.filter (ehServidor puzzle)
        |> List.concatMap
            (\posicao ->
                [ { posicao | coluna = posicao.coluna + 1 }, { posicao | linha = posicao.linha + 1 } ]
                    |> List.filter (ehServidor puzzle)
                    |> List.map (ServidoresEncostados posicao)
            )


{-| Vitória: nenhum conflito, e cada carga e cada sensor com o número exato.
Uma casa sem marca conta como livre, então o jogador não precisa marcar
"livre" em tudo para ganhar.
-}
venceu : Puzzle -> Bool
venceu puzzle =
    List.isEmpty (conflitos puzzle)
        && cargasBatem puzzle.cargasLinha (\i -> servidoresNaLinha i puzzle)
        && cargasBatem puzzle.cargasColuna (\j -> servidoresNaColuna j puzzle)
        && List.all (\( posicao, numero ) -> servidoresEmVolta posicao puzzle == numero) (sensores puzzle)


cargasBatem : Array Int -> (Int -> Int) -> Bool
cargasBatem cargas contar =
    Array.toIndexedList cargas
        |> List.all (\( indice, carga ) -> contar indice == carga)



-- TEXTOS


{-| Linhas e colunas aparecem numeradas a partir de 1, como o jogador as conta.
-}
descreverMotivo : Motivo -> String
descreverMotivo motivo =
    case motivo of
        PorLinha linha ->
            "A carga da linha " ++ numeroParaJogador linha ++ " só fecha com este valor nesta casa."

        PorColuna coluna ->
            "A carga da coluna " ++ numeroParaJogador coluna ++ " só fecha com este valor nesta casa."

        PorSensor posicao ->
            "O sensor na " ++ descreverPosicao posicao ++ " só fecha com este valor nesta casa."

        PorRefrigeracao posicao ->
            "Esta casa encosta no servidor da " ++ descreverPosicao posicao ++ ", e dois servidores não podem ficar lado a lado."

        Combinado ->
            "Nenhuma regra sozinha decide esta casa: é preciso combinar as regras."


descreverPosicao : Posicao -> String
descreverPosicao { linha, coluna } =
    "linha " ++ numeroParaJogador linha ++ ", coluna " ++ numeroParaJogador coluna


numeroParaJogador : Int -> String
numeroParaJogador indice =
    String.fromInt (indice + 1)


dificuldadeTexto : Dificuldade -> String
dificuldadeTexto dificuldade =
    case dificuldade of
        Facil ->
            "Fácil"

        Medio ->
            "Médio"

        Dificil ->
            "Difícil"
