# Coleção de legendas — validação real

Estas imagens são produzidas pelo código do app, não por um gerador de imagens. A frase de
comparação é **“Sua ideia merece ganhar vida.”**; `merece` é a palavra ativa nos quatro estilos
com acompanhamento. Clean não destaca palavras por padrão.

## Frames decodificados da exportação

| Cue | Impacto | Clean | Pop | Editorial |
| --- | --- | --- | --- | --- |
| ![Cue](cue-export.png) | ![Impacto](impact-export.png) | ![Clean](clean-export.png) | ![Pop](pop-export.png) | ![Editorial](editorial-export.png) |

O fundo verde pertence ao vídeo sintético de teste; não é parte do estilo. O teste exporta um
MOV de verdade e extrai o frame em 1,4 s. Compara-o à composição usada pelo player, testa o fim
da legenda e confirma que o vídeo original não foi alterado. Cada coluna também tem
`<estilo>-preview.png` (prévia) e `<estilo>.png` (legenda com transparência, 1080p).

## Cobertura

Rodada focada de renderização/exportação: **47 testes passaram**, nenhuma falha (seis suítes).
A rodada complementar final de editor, cache, biblioteca e exportação no view model passou
com **58 testes**, incluindo cancelar ao desligar e preservar o áudio sem efeitos adicionais.
Os dois XCUITests passaram. Na última rodada ampla: **1.088 aprovados, duas falhas fora do escopo
e quatro testes opt-in ignorados**, em 1.094 testes reportados pelo Xcode.
Uma repetição ampla excedeu o tempo ao gerar novamente o vídeo sintético no simulador; o teste
de exportação agora compartilha uma origem imutável entre os casos, registra cada etapa e passou
novamente em todos os estilos. Nenhuma falha anterior foi descartada dos relatórios locais.

Na comparação de frames da rodada completa com cinco exports aprovados, a diferença média
prévia/export foi Cue 0,47; Impacto 0,49; Clean 0,46; Pop 0,57; Editorial 0,43, numa escala RGBA
de 0–255 (limite do teste: 3, para diferenças de escala/codec). Quebras, posição e palavra ativa
também foram inspecionadas visualmente nos PNGs acima.

- `CaptionCollectionRendererTests`: cinco estilos, fontes incorporadas, pesos variáveis,
  layout estável por palavra, 15 idiomas, alternativa estática sem tempos confiáveis,
  correções que pedem revisão, persistência e receita antiga sem migração visual.
- `CaptionCollectionExportTests`: cinco exportações reais com legendas, aparência e tempos
  comparados com a prévia; exportação sem legendas e preservação do original.
- `CaptionTimelineMappingTests`: trim nas duas bordas, exclusão no meio, split sem salto,
  velocidade, reordenação, cópias e montagem com takes de origens diferentes.
- `CaptionBuilderTests`: roteiro empresta apenas grafia/pontuação de correspondências confiáveis;
  fala alterada, improvisação, repetição e frases puladas permanecem corretas; pausas delimitam
  frases. Trechos sem limites por palavra mantêm o tempo real do segmento, sem divisão arbitrária.
  `CleanUpAnalyzerTests` confirma que esse resultado compartilhado não pode propor remover uma
  frase inteira por causa de um filler sem tempo individual; a detecção de pausas é preservada.
- `QuickEditCaptionsTests` / `TakeReviewViewModelTests` / `TakeLibraryServiceTests`: modos com/sem
  script, texto independente do roteiro, falha/retry/cancelamento, undo, cache de reconhecimento,
  controles visuais sem retranscrever e exportação com resultado reutilizável.
- `TakeScriptReferenceTests`: roteiro congelado sobrevive a alteração/exclusão e serialização;
  take antiga não usa um roteiro cuja versão mudou.
- XCUITest: catálogo de cinco opções, seleção e ajustes secundários, escolha mantida após Done
  e reabertura, catálogo de textos antigo preservado no outro escopo.

## Limitações explícitas

- A imagem conceitual mencionada no pedido não estava disponível nos anexos desta conversa.
  Os estilos foram implementados a partir da especificação escrita; falta comparação direta
  com essa imagem para confirmar fidelidade pixel a pixel.
- O reconhecedor existente continua sendo Apple SpeechAnalyzer, local. A disponibilidade varia
  por idioma/dispositivo; baixar um modelo requer conexão. O simulador não executa reconhecimento
  real: a captura de câmera/microfone e a precisão acústica devem ser conferidas num iPhone.
  Foram validados o pipeline e o alinhamento com transcrições controladas, não uma gravação humana.
- Se Speech só informar um intervalo para várias palavras, a legenda desse trecho é estática.
  Não há destaque com precisão inventada. Correções com novas palavras recebem “Check timing”.
  Um corte parcial nesses segmentos também pede revisão: os limites visuais são cortados,
  mas não há evidência acústica para escolher automaticamente quais palavras do segmento retirar.
- Para takes antigas sem referência congelada, um roteiro já alterado não pode ser recuperado;
  a legenda existente é preservada e uma nova geração se baseia no áudio.
- A execução ampla da suíte encontrou falhas em testes não modificados de ruído/Voice Following
  e leitura do arquivo de entitlements no repositório (bloqueada pelo sandbox do simulador).
  Elas não estão ocultadas nem fazem parte da validação positiva da coleção.

## Reprodução

Use Xcode 27 com SwiftLint no PATH e `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
No scheme compartilhado, execute as suítes acima no iPhone 17 Simulator. Os testes de exportação
devem rodar com `-parallel-testing-enabled NO`, evitando competição entre codecs/simuladores.
Os PNGs são attachments dos testes, exportáveis por `xcresulttool export attachments`.

Além dos testes, os builds limpos Debug para iPhone e Release para Simulator foram conferidos
sem warnings; SwiftLint foi executado com `--no-cache`. Os relatórios locais `.xcresult` ficam
fora do Git para não versionar containers e vídeos temporários.
