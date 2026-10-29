# Áudio do Cue: origem, licenças e decisões (Fase 8, 29 de outubro de 2026)

O que o editor oferece de som próprio (músicas da biblioteca, efeitos sonoros, narração a partir de texto, efeitos de voz), de onde vem
cada coisa, o que o criador pode fazer com ela, o que foi avaliado e descartado, e como ampliar. As telas estão em `DESIGN_PROJECT.md` §56.

## 1. Músicas da biblioteca (`CueTrack`, `music-library.json`)

**Origem:** vinte faixas **compostas pelo Cue** (partituras em `tools/music/tracks/`: acordes, melodias, baixo, bateria, seções) e
**tocadas por instrumentos gravados** de bibliotecas de samples gratuitas (`tools/music/instruments.py`, `sampler.py`), mixadas e
masterizadas fora do app (−16 LUFS integrado, pico verdadeiro até −1 dBTP) e **embutidas no app**: `SupportFiles/Sounds/Music/music-<id>.m4a`
(AAC 128 kbps, 48 kHz estéreo; o prefixo existe porque o Xcode copia os recursos de uma pasta sincronizada sem subpastas para o bundle).
Nada é feito nem baixado no aparelho: ouvir é tocar o arquivo do bundle e adicionar liga esse arquivo à mídia da edição (link físico,
ou uma cópia onde o sistema não deixa ligar a partir do bundle), então uma faixa refeita numa versão nova do app nunca muda uma edição
já feita. As melodias e progressões são originais (progressões comuns de acordes não são protegidas; nenhuma melodia conhecida foi usada).

O que o app sabe de cada arquivo vem de `SupportFiles/Sounds/music-library.json`, escrito pela mesma exportação
(`tools/music/export_app.py`) e lido uma vez (`CueTrackFacts`): duração exata, BPM, compasso, as batidas (uma por semínima, da
primeira cabeça de compasso ao acorde final, tiradas da partitura; vão prontas para Beats), se a faixa foi composta para ficar sob a
fala (`forTalking`) e as bibliotecas que ela toca (`sources`). O que a biblioteca mostra (estilo, uso, humor, "For talking") fica em
`CueTrack+Library.swift`. `MusicLibraryBundleTests` confere que cada `CueTrack` tem arquivo e entrada (e vice-versa), que o arquivo
decodificado tem a duração do manifesto (±0,02 s), 48 kHz estéreo, batidas crescentes, dentro da faixa e espaçadas 60/BPM, que
"For talking" bate com o manifesto e que toda biblioteca citada é conhecida.

| Faixa | Estilo no app | BPM | Duração | Sob a fala | Bibliotecas |
|---|---|---|---|---|---|
| Morning Notes | violão | 92 | 86,5 s | sim | FreePats guitar, Swirly Drums, VSCO 2 |
| Late Study | lo-fi hip-hop (piano de armário Knight, VCSL) | 82 | 88,9 s | sim | Swirly Drums, VCSL, VSCO 2 |
| Bright Side | pop acústico (piano, violão de náilon, bateria, marimba e glockenspiel) | 118 | 76,8 s | não | FreePats guitar, VCSL, Virtuosity Drums, VSCO 2 |
| First Light | construção cinematográfica (piano, cordas, tímpanos, metais) | 84 | 52,3 s | não | VCSL, VSCO 2 |
| Clean Slate | marimba minimalista (marimba, contrabaixo, vibrafone) | 110 | 73,9 s | sim | Swirly Drums, VCSL, VSCO 2 |
| Neon Overpass | nu-disco tocado por orquestra (bateria, cordas, metais, congas) | 112 | 72,1 s | não | VCSL, Virtuosity Drums, VSCO 2 |
| Tiptoe Parade | marimba e madeiras (fagote, clarinete, pizzicato) | 124 | 55,7 s | não | VSCO 2 |
| Slow Tide | ambiente (Steinway, VCSL) | 70 | 101,1 s | sim | VCSL, VSCO 2 |
| Wide Open | piano (Steinway, VCSL) e cordas, para conselhos e negócios | 104 | 81,5 s | sim | VCSL, Virtuosity Drums, VSCO 2 |
| Quiet Hours | piano solo (Steinway, VCSL) | 76 | 92,5 s | sim | VCSL |
| Golden Hour | bossa nova (violão de náilon, baixo, vassourinhas, flauta) | 128 | 67,3 s | sim | FreePats guitar, Swirly Drums, VCSL, VSCO 2 |
| Corner Booth | trio de jazz (piano, contrabaixo, vassourinhas), em swing | 132 | 69,5 s | sim | Swirly Drums, VCSL, VSCO 2 |
| Back Porch | folk-pop (violão de náilon, cajón, violinos, glockenspiel) | 104 | 86,6 s | sim | FreePats guitar, VCSL, VSCO 2 |
| Night Shift | hip-hop chill (boom-bap suave, piano abafado, kalimba) | 86 | 93,4 s | sim | VCSL, Virtuosity Drums, VSCO 2 |
| Cold Case | suspense (cellos em pizzicato, violas, piano, tímpanos, sino), sem bateria | 92 | 78,1 s | sim | VCSL, VSCO 2 |
| Kind Words | valsa terna em 3/4 (piano, cordas, harpa) | 84 | 81,7 s | sim | VCSL, VSCO 2 |
| Snow Globe | swing natalino (vassourinhas, guizos só no contratempo, pizzicato, sinos) | 120 | 77,1 s | sim | Swirly Drums, VCSL, VSCO 2 |
| Island Hop | tropical (marimba, cajón, congas, violão de náilon, kalimba) | 100 | 80,4 s | sim | FreePats guitar, VCSL, VSCO 2 |
| Full Send | rock orquestral (piano, bateria, tímpanos, metais) | 128 | 63,6 s | não | VCSL, Virtuosity Drums, VSCO 2 |
| Still Water | meditação (cordas longas, sinos, kalimba, harpa), sem bateria | 64 | 82,1 s | sim | VCSL, VSCO 2 |

Todas as faixas são tocadas por instrumentos gravados (Kind Words é em 3/4; as batidas do manifesto seguem a semínima). Durações e bibliotecas da tabela são as da exportação de 29/10
(só CC0); o manifesto é a fonte.

**Medidas da exportação de 29/10** (`render.py` e `export_app.py --check`):
- Todas as 20 ficam em −16,0 LUFS, com pico verdadeiro entre −3,6 e −7,9 dBTP e nenhum clique.
- Energia na faixa da voz (1–4 kHz, parte do total):
  - nas 15 feitas para ficar sob a fala, entre −14,9 dB (Wide Open) e −21,8 dB (Morning Notes);
  - nas 5 de abertura e montagem, entre −10,3 e −12,3 dB.
- Nenhuma tem chiado, crepitar de vinil ou um fundo de ruído contínuo; os chocalhos, onde há, tocam baixo e no ritmo. A bateria das
  faixas sob a fala é de vassourinha ou suave e abafada.

**Formato: AAC 128 kbps** (decisão de 29/10, medida). As 20 faixas somam 26,4 MB no app. Comparadas depois do caminho que o público
ouve (decodificar, exportar em AAC 192 kbps, recomprimir em AAC 128 kbps a 44,1 kHz como Instagram/TikTok), em distância espectral
média por banda ao original sem perda, onde o próprio original sem perda fica em −21,0 dB depois do caminho:

| Formato | 20 faixas | Distância ao original |
|---|---|---|
| AAC 128 kbps, o atual | 26,4 MB | −19,3 dB |
| AAC VBR, qualidade 64 | 24,2 MB | −18,6 dB |
| AAC VBR, qualidade 54 | 20,0 MB | −17,9 dB (corta acima de 16 kHz) |
| HE-AAC 80 kbps | 15,7 MB | −17,0 dB |
| Opus 96 kbps (CAF) | 14,2 MB | −14,6 dB |

- O AAC 128 é o mais fiel, e por isso ficou. Os menores economizam até 12 MB, mas perdem mais justamente onde o vídeo é recomprimido
  duas vezes.
- O xHE-AAC não tem codificador no macOS.
- Todos os outros abrem, são lidos por inteiro e exportam pelo AVFoundation no Mac, como o editor faz (AVAssetReader e uma composição
  exportada). A exportação do app sempre gera AAC novo, então o formato embutido não muda nada para as redes sociais.
- Baixar as faixas depois da instalação (Background Assets hospedados pela Apple) não reduz o espaço no aparelho e cria uma dependência
  de rede.

**Bibliotecas de samples** (`SoundSource`; licença em `SupportFiles/Licenses/CC0-1.0.txt`, listadas em Ajustes › Acknowledgements só
as que o app usa). **Todas CC0** (decisão do dono, 29/10: nada que exija crédito; o Salamander Grand Piano e o Wurlitzer de Greg Sullivan,
CC BY 3.0, saíram, e os pianos vêm do Steinway e do piano de armário Knight da VCSL):

| Biblioteca | Autor | Licença | Crédito |
|---|---|---|---|
| VSCO 2 Community Edition | Versilian Studios | CC0 1.0 | não |
| Versilian Community Sample Library (VCSL) | Versilian Studios | CC0 1.0 | não |
| Virtuosity Drums | Versilian Studios e Karoryfer Samples, tocada por Austin McMahon | CC0 1.0 | não |
| Swirly Drums | Karoryfer Samples | CC0 1.0 | não |
| Spanish Classical Guitar | FreePats project | CC0 1.0 | não |
| Kenney (Interface, UI, RPG, Casino) | Kenney | CC0 1.0 | não (só efeitos) |

Endereços e commits de cada uma: `~/Desktop/Projects/CueStudio-Audio/sources/PROVENANCE.txt`.

**Termos mostrados ao criador** (ⓘ de cada faixa, `MusicTrackLicence(sources:)`, a partir das bibliotecas do manifesto):
- Origem: "Composed by Cue and played on recorded instruments from free sample libraries (credited in Settings › Acknowledgements)."
- Termos: "Free to use in the videos you make, monetized ones included."
- Crédito: "No credit needed." em todas (as bibliotecas são CC0). O código é geral: uma biblioteca cuja licença pedisse crédito ganharia um
  caso em `SoundSource.Licence` e as faixas que a tocam diriam "Credit in your video: <biblioteca> by <autor> (<licença>)".
- "Sample libraries: …" com as bibliotecas da faixa.

**O que fica registrado no projeto:** cada clipe de música guarda qual faixa é (`MusicClip.libraryTrack`), e com ela a origem, os
termos e o crédito; um arquivo dos Files fica sem (a nota da folha continua: "Use only music you own or have the rights to").

> **Decisão do dono pendente:** os termos acima são uma licença que o Cue concede sobre música que ele compõe; as gravações dos
> instrumentos são de terceiros sob CC0 (domínio público: uso comercial e redistribuição sem condição). Antes do lançamento, confirmar o
> texto (e, se quiser, publicá-lo nos Termos de uso). As faixas não estão registradas em nenhum sistema de identificação de conteúdo
> (Content ID e parecidos), então nada reivindica um vídeo por usá-las; isso também quer dizer que, se alguém registrar uma gravação
> delas, o Cue não tem como contestar por um registro próprio.

**Por que não há catálogo de terceiros** (pesquisado em outubro de 2026; nada baixado):

| Fonte | Por que não entrou |
|---|---|
| Músicas comerciais | Proibido pelo pedido; sem licença de sincronização. |
| Pixabay Music, Uppbeat (grátis), Mixkit | A licença permite usar em vídeos, **não redistribuir** as faixas dentro de outro app ou biblioteca; várias faixas estão no Content ID e geram reivindicação. "Royalty-free" não é uso irrestrito. |
| Biblioteca de Áudio do YouTube | Termos só para vídeos no YouTube; não pode ser embutida em app. |
| Apple Loops (GarageBand/Logic) | Licença para usar em músicas próprias, não para redistribuir os loops como biblioteca de outro app. |
| Free Music Archive / Creative Commons | Licenças variam por faixa (BY, BY-SA, NC, ND); NC proíbe vídeos monetizados, BY exige crédito em cada vídeo; seria preciso conferir e guardar a licença de cada faixa. |
| FreePD, Musopen e outras em domínio público / CC0 | Possível no futuro (ver §5), mas a qualidade é desigual e a origem de cada faixa precisa ser verificada uma a uma. |
| Epidemic Sound, Artlist, Soundstripe (pagos, com API) | Dependem de contrato e credenciais; não contratados sem autorização do dono. |

## 2. Efeitos sonoros (`SoundEffect`, `SoundEffectFiles`, `SoundEffectSynth`)

42 efeitos em seis grupos por uso (`SoundEffectCategory`), e um lugar só que diz onde está o arquivo de cada um (`SoundEffectFiles`):

- **32 gravados**, embutidos no app (`SupportFiles/Sounds/Effects/sfx-<id>.caf`, ALAC 48 kHz mono 16 bits): objetos e instrumentos
  reais das bibliotecas CC0 VSCO 2, VCSL, Virtuosity Drums e Kenney, montados e nivelados fora do app (`tools/music/sounds.py`,
  `variants.py`; o dono escolheu efeito por efeito, 29/10). São os 16 de antes que viraram gravação (Whoosh, Riser, Click, Double
  click, Typing, Coin, Boom, Drum roll, Heartbeat, Ping, Bloop, Pop, Boing, Hit, Sparkle, Shutter) e **16 novos**: Page turn (uma
  página virada), Dream harp (glissando de harpa), Footsteps (passos num piso), Fanfare (o ta-da de metais gravado, ao lado do Ta-da
  sintetizado), Cash register (trinco, sino e moedas), Referee whistle (um apito curto), Ba-dum-tss (caixa, tom e prato num kit
  real), Record scratch (um compasso de bateria, baixo e vibrafone parado na mão), Slap (o estalo de um slapstick), Clang (martelo num
  tambor de freio e uma bigorna), Slide whistle (apito de êmbolo subindo e descendo), Cartoon run (xilofone subindo a escala), Sneaky
  (pizzicato na ponta dos pés), Dramatic sting (metais e tímpanos, "dun dun duuun"), Gong e Bleep (o tom de 1 kHz da censura).
- **10 sintetizados** no aparelho por `SoundEffectSynth` (escolha do dono: soam melhor assim): Swish, Bass drop, Glitch, Tick, Ding,
  Wrong, Ta-da, Sad trombone, Countdown e Tick-tock. O arquivo é feito na primeira vez em `Caches/SoundEffects/<id>-v<versão>.caf`.

Todos têm a mesma intensidade percebida: a janela de 400 ms mais alta, com K-weighting da ITU-R BS.1770, em −14 LUFS, com pico limitado
a −3 dBFS (0,708); um som curto e seco para no pico e fica um pouco mais baixo. A exportação aplica a mesma regra às gravações, e
`SoundEffectFilesTests` confere cada arquivo embutido (mono, 48 kHz, ≥ 0,5 s, loudness ≤ −13,5 LUFS pelo `SoundEffectSynth.loudness(of:)`
do app, pico ≤ 0,71), que todo efeito tem um arquivo (gravado ou sintetizado, nunca os dois), que cada grupo tem efeitos e cada efeito
nome, uso e um SF Symbol que existe. Um efeito posto numa edição é ligado à mídia dela, então trocar o arquivo nunca muda uma edição.

**Termos:** a folha diz "Free to use in your videos · no credit needed": as bibliotecas dos efeitos são todas CC0 (nada a creditar); os
sintetizados são do Cue.

## 3. Narração a partir de texto (`NarrationMaker`, `SystemNarrationSpeaker`)

Vozes do sistema (`AVSpeechSynthesizer.write`), **no aparelho e sem internet**; nenhum serviço em nuvem. A folha lista só as vozes que
o iPhone tem, por idioma, as melhores primeiro (Premium, Enhanced, padrão; na mesma qualidade, a voz padrão do idioma primeiro e as
Eloquence, como Eddy, Flo e Reed, por último, porque soam mais mecânicas); quando um idioma só tem vozes compactas, uma nota diz onde
baixar melhores (Ajustes › Acessibilidade › Conteúdo Falado › Vozes). Vozes "personal voice" e as de novidade (Bells, Bad News…) ficam
de fora. A velocidade (0,75×–1,5×) é exata: a voz fala no ritmo padrão e o áudio é esticado sem mudar o tom
(`CurveSoundRenderer`), porque o `rate` do sintetizador não é proporcional (medido: 0,55 → 1,27–1,29×; 0,6 → 1,59–1,62×; 0,4 e 0,45
iguais em algumas vozes). O silêncio que a voz deixa no começo e no fim é cortado; a fala é posta em −18 dBFS de potência média (`SpeechLoudness`, só os trechos falados), pico abaixo do teto de `AudioCeiling`. Cada narração
guarda o texto, a voz, o idioma e a velocidade (`VoiceOverClip.spoken`) para Edit text refazer no mesmo lugar.

**Medido no iPhone 15 Pro** (`AudioMixDeviceTests`, 29/10; o reconhecimento de fala do próprio iPhone, sem o texto como dica, conta as
palavras entendidas em ordem): a duração bate com a velocidade pedida (0,750× / 1,250× / 1,500× do 1×), a narração de um parágrafo de ~11 s fica
pronta em 0,5–0,8 s, e o entendido, com a primeira voz que a folha oferece (a padrão do idioma; o iPhone só tinha vozes compactas), foi:

| Idioma, voz | 0,75× | 1× | 1,25× | 1,5× |
|---|---|---|---|---|
| Inglês (EUA), Samantha | 93% | 93% | 93% | 93% |
| Espanhol (Espanha), Mónica | 100% | 100% | 100% | 100% |
| Português (Brasil), Luciana | 97% | 100% | 100% | 100% |

(Os 7% que faltam em inglês são "three"→"3" e "first"→"1st", escritos em número pelo reconhecedor.) Com a regra antiga (só por nome) a primeira
oferecida em português e espanhol era Eddy, uma voz Eloquence: 86–97% em português. Numa das rodadas, o iPhone disse por um instante que a voz
que tinha acabado de falar não existia (logo depois do reconhecimento de fala rodar); o app agora pergunta de novo por até 2 s antes de dar erro,
e a rodada seguinte passou inteira (não dá para afirmar que foi isso que resolveu).

**Limites:** a qualidade é a das vozes do sistema (as compactas soam robóticas; Enhanced e Premium precisam ser baixadas pelo
criador); o texto vai até 3.000 caracteres; não há controle de entonação, ênfase ou pausas além da pontuação.

## 4. Efeitos de voz (`VoiceEffect`, `VoiceEffectRenderer`)

Sete efeitos criativos, separados do Studio Voice (que cuida da inteligibilidade e continua por baixo): Radio, Megaphone, Robot,
Deep voice, Chipmunk, Echo e Big hall, com **Amount** (10–100%) e ◐ para ouvir sem. Processados no aparelho (filtros biquad,
saturação, modulação em anel, linha de atraso, reverb Freeverb, mudança de tom com `AVAudioUnitTimePitch`), com a mesma duração da
voz até a amostra e a mesma intensidade (±1,5 dB) para a comparação ser justa. None devolve a voz como era.

**Medido no iPhone 15 Pro** (`AudioMixDeviceTests`, 29/10): um parágrafo em inglês de 11,4 s (voz Aaron) passou por cada efeito com o Amount
inicial (70%) e foi ouvido pelo reconhecimento de fala do próprio iPhone. Sem efeito: 93% das palavras. Com efeito:

| Efeito | Entendido | Feito em | Tempo real |
|---|---|---|---|
| Radio | 93% | 0,32 s | 35× |
| Megaphone | 93% | 0,30 s | 38× |
| Robot | 93% | 0,28 s | 40× |
| Deep voice | 93% | 0,18 s | 63× |
| Chipmunk | 90% | 0,17 s | 67× |
| Echo | 93% | 0,24 s | 48× |
| Big hall | 95% | 0,54 s | 21× |

A duração de cada um ficou igual à da voz (diferença abaixo de 0,05 s). O reconhecimento mede se as palavras continuam claras, não se o
efeito soa bem: isso só uma pessoa ouvindo diz.

## 5. Como ampliar a biblioteca

1. **Mais uma faixa do Cue:** compor a partitura em `tools/music/tracks/<nome>.py`, renderizar e ouvir/medir (`tools/music/render.py`;
   só bibliotecas de `instruments.py`, de preferência CC0); com a aprovação do dono, pôr a faixa em `MUSIC` de `tools/music/export_app.py`
   (id do app → módulo) e rodar `venv/bin/python tools/music/export_app.py` (`--check` antes: mede sem escrever), que escreve
   `music-<id>.m4a` e a entrada em `music-library.json` (só bibliotecas CC0, decisão do dono). No app: a `case` em `CueTrack.swift` com o título (nome próprio, sem tradução);
   estilo, uso, humor e se é para fala em `CueTrack+Library.swift` (o "para fala" igual ao `forTalking` do manifesto); os textos novos
   nos 20 idiomas (`scripts/strings.py add`); se a faixa usar uma biblioteca nova, a `case` em `SoundSource` (nome, autor, endereço, o que
   tem; a chave é a de `LIBRARIES` do `export_app.py`). `MusicLibraryBundleTests`, `MusicLibraryViewModelTests` e `SoundSourceTests` dizem o que faltou.
2. **Mais um efeito:** a receita em `tools/music/sounds.py` (ou `variants.py`), renderizar, ouvir; aprovado, pôr em `EFFECTS` de
   `export_app.py` e exportar (`sfx-<id>.caf`). No app: a `case` em `SoundEffect` no grupo certo, com nome, uso, SF Symbol (conferir que
   existe no SDK) e grupo; os textos nos 20 idiomas. Um efeito sintetizado em vez de gravado ganha a receita em `SoundEffectSynth.recipes`
   (e `SoundEffect.version` sobe se uma receita existente mudar). Se usar outra biblioteca, ela entra em `SoundSource.soundEffectSources`.
   `SoundEffectFilesTests` e `SoundEffectSynthTests` dizem o que faltou.
3. **Faixas licenciadas de fora** (só com autorização do dono): cada faixa com origem, licença exata (link e cópia do texto), crédito
   exigido e data da verificação; nenhuma faixa NC/ND; conferir se está em Content ID. O arquivo iria no bundle ou num download próprio
   do Cue, nunca de um serviço de terceiros sem contrato.
4. **Catálogo pago com API:** exige contrato, credenciais, e mostrar os termos do fornecedor por faixa.
