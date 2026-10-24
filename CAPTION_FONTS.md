# Fontes da coleção de legendas

Arquivos incorporados ao bundle, registrados por `CueStudioFont`: não há API de fontes na prévia
nem na exportação. Interface e teleprompter continuam com sua tipografia existente.

| Estilo | Arquivo | Peso | Origem e licença incluída |
| --- | --- | --- | --- |
| Cue | SpaceGrotesk-Variable.ttf | 700 | [Space Grotesk](https://github.com/google/fonts/tree/main/ofl/spacegrotesk), spacegrotesk-OFL.txt |
| Impacto | Anton-Regular.ttf | corte único | [Anton](https://github.com/google/fonts/tree/main/ofl/anton), anton-OFL.txt |
| Clean | Inter-Variable.ttf | 600 | [Inter](https://github.com/google/fonts/tree/main/ofl/inter), inter-OFL.txt |
| Pop | Poppins-ExtraBold.ttf | 800 | [Poppins](https://github.com/google/fonts/tree/main/ofl/poppins), poppins-OFL.txt |
| Editorial | Manrope-Variable.ttf (edits saved antes: v1) · DMSerifDisplay-Regular.ttf (v2) | 700 · corte único | [Manrope](https://github.com/google/fonts/tree/main/ofl/manrope), manrope-OFL.txt · [DM Serif Display](https://github.com/google/fonts/tree/main/ofl/dmserifdisplay), dmserifdisplay-OFL.txt |
| Educational | Manrope-Variable.ttf | 700 | Manrope (a mesma do Editorial v1) |
| Interview | Inter-Variable.ttf | 600 | Inter (a mesma do Clean) |

Nenhuma fonte nova entrou no bundle: os presets completos (`CaptionStyleSpec`, versão 2) reaproveitam as
cinco da coleção e a DM Serif Display, já incorporada para os textos. Os edits salvos antes (`styleVersion`
ausente) continuam com os números e as fontes da primeira leitura.

## O catálogo (versão 3)

Os vinte estilos (`CaptionStyleSpec+Catalog`) usam só fontes já incorporadas: as da coleção (Space Grotesk,
Inter, Manrope, Anton, Poppins ExtraBold, DM Serif Display) e as do editor (`TextOverlayFont.editorFonts`), pela
família e pelo peso (`CaptionStyleSpec.face`):

| Estilo | Família · peso | Estilo | Família · peso |
| --- | --- | --- | --- |
| Cue | Space Grotesk 700 | Condensed | Anton |
| Glide | Rubik 800 | Bold | Montserrat 800 |
| Spotlight | TikTok Sans 800 | Comic | Bangers |
| Reveal | Poppins 700 | Punch | Unbounded 800 |
| Clean | Inter 600 | Serif | DM Serif Display |
| Dark box | Manrope 700 | Paper | Instrument Serif |
| Outline | Montserrat 800 | Interview | DM Sans 500 |
| Band | DM Sans 700 | Mono | Space Mono Bold |
| Violet | Poppins ExtraBold | Light pill | Rubik 700 |
| Coral | Syne 800 | Cyan night | Space Grotesk 700 |

Caption style › Adjust oferece só os pesos que a família tem (`CaptionStyleSpec.availableWeights`: Inter, Manrope e
Space Grotesk pelo eixo `wght`; as do editor pelos seus cortes; Anton, Bangers, DM Serif, Instrument Serif e Space
Mono têm um só, e a linha de peso some). A mesma cobertura vale: um idioma que a família não tem sai na fonte do
sistema, no peso de reserva do estilo, e o cartão do estilo mostra isso com as palavras do próprio vídeo.

Distribuições oficiais do Google Fonts baixadas em 2026-09-30, sob SIL Open Font License 1.1,
com os avisos de copyright preservados. Fontes anteriores não foram removidas: atendem ao
teleprompter, textos e receitas de projetos anteriores.

Space Grotesk registra o nome PostScript `SpaceGrotesk-Light`; `CaptionFont` seleciona o eixo
`wght` explicitamente para renderizar Bold. Não se simula negrito com nome inexistente.

## Cobertura e alternativas locais

`CaptionFont` verifica os glifos antes de usar a fonte incorporada. Se faltar cobertura, usa a
família de sistema iOS no peso compatível e a cascata local do TextKit, incluindo japonês, coreano,
chinês simplificado, hindi, árabe e tailandês. Isso também cobre eventuais acentos ausentes nas
famílias display; não substitui caracteres nem baixa fontes. Árabe mantém RTL e modelagem contextual.
A alternativa pode diferir da família latina, mas usa a mesma composição na prévia e exportação.

Os testes renderizam exemplos dos 15 idiomas do app, incluindo português, turco e vietnamita.
Cobertura tipográfica não significa disponibilidade de um modelo de fala: a infraestrutura Speech
existente consulta o suporte do dispositivo separadamente.
