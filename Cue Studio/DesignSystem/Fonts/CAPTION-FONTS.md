# Fontes da coleção de legendas

Arquivos incorporados ao bundle, registrados por `CueStudioFont`: não há API de fontes na prévia
nem na exportação. Interface e teleprompter continuam com sua tipografia existente.

| Estilo | Arquivo | Peso | Origem e licença incluída |
| --- | --- | --- | --- |
| Cue | SpaceGrotesk-Variable.ttf | 700 | [Space Grotesk](https://github.com/google/fonts/tree/main/ofl/spacegrotesk), spacegrotesk-OFL.txt |
| Impacto | Anton-Regular.ttf | corte único | [Anton](https://github.com/google/fonts/tree/main/ofl/anton), anton-OFL.txt |
| Clean | Inter-Variable.ttf | 600 | [Inter](https://github.com/google/fonts/tree/main/ofl/inter), inter-OFL.txt |
| Pop | Poppins-ExtraBold.ttf | 800 | [Poppins](https://github.com/google/fonts/tree/main/ofl/poppins), poppins-OFL.txt |
| Editorial | Manrope-Variable.ttf | 700 | [Manrope](https://github.com/google/fonts/tree/main/ofl/manrope), manrope-OFL.txt |

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
