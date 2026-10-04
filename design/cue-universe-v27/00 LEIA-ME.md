# Cue Universe — pacote de design v27

Este pacote leva a nova personalidade do Cue Studio ("cada criador tem um universo") para o Claude Design e para o Claude Code. Os fluxos e a lógica da v26 continuam os mesmos. O que muda é a pele, o movimento, os ícones, os controles e algumas telas novas.

**Canvas ao vivo (com todas as animações):** https://claude.ai/artifact/Hp4M32mkCAz1nTkxPeLSRx (página "Final workflow")

## O que tem aqui

| Item | O que é |
| --- | --- |
| `00 Workflow overview.png` | As 47 telas, em ordem, numa imagem só |
| `01 Direção de design — Cue Universe.md` | **Comece por aqui.** O conceito do criador viajante, a jornada, os princípios, como o tema aparece em animações, ícones, textos e interface, e as decisões tomadas |
| `02 Onboarding motion storyboard.png` | Os momentos-chave do "primeiro voo" |
| `02b In-app motion storyboard.png` | Os momentos-chave dentro do app: roteiro, contagem, teleprompter, melhor take, som, despedida, marco, ajustes |
| `03 Screens — PNG @3x/` | Todas as telas em imagem (0.1–0.3 são os quadros de sistema) |
| `04 Screens — HTML source/` | As mesmas telas em HTML. **Abra no navegador para ver as animações.** |
| `05 Icons/in-app/` | Os 53 ícones v2 em SVG |
| `05 Icons/app-icons/` | As camadas dos 4 ícones alternativos do app (1024 px) |
| `06 Specs/DESIGN-SPEC.md` | Especificação técnica (em inglês): cores, tipografia, orbs, céu, movimento, haptics, permissões, acessibilidade |
| `06 Specs/SCREENS.md` | Mapa das telas: o que cada uma faz, o equivalente na v26 e a fase |
| `06 Specs/strings-en.csv` | Os textos em inglês de cada tela, com sugestão de chave para o String Catalog |
| `07 Prompts/` | Os dois prompts prontos |

## Como usar

1. **Claude Design (recomendado primeiro).**
   - Abra o projeto da v26.
   - Anexe esta pasta e cole o prompt `07 Prompts/1 — PROMPT Claude Design (create v27).md`.
   - Ele cria a v27 aplicando a direção a todas as telas da v26, inclusive as que não estão aqui.
2. **Claude Code.**
   - Coloque esta pasta (e o export da v27, se tiver) em `design/cue-universe-v27/` no repositório.
   - Cole o prompt `07 Prompts/2 — PROMPT Claude Code (build in phases).md`.
   - Ele trabalha em fases (fundação → lançamento → 1ª atualização → depois), com um PR por fase.

## Bom saber

- **As imagens PNG usam fontes substitutas.** A Geist e as fontes do editor não puderam ser carregadas aqui, então as imagens usam Inter e DejaVu. No canvas e no HTML aberto com internet, as fontes certas aparecem. No app, a interface usa SF Pro e SF Mono.
- **As animações dos quadros ficam em loop** só para você poder revisar. No app, as sequências de história (boas-vindas, capítulos, despedida, marco, primeira estrela) tocam uma vez.
- **Preço mensal em aberto:** $7.99 ou $9.99. Isso se define no App Store Connect, não no código.
- **Fontes do editor:** todas têm licença SIL Open Font License (gratuitas, podem ser embutidas no app). Inclua o arquivo de licença de cada uma em Settings › About › Licenses.
- **Revisão da Apple:**
  - Na tela de permissões, o botão diz "Continue", sem "Allow", sem "Skip" e sem "Not now".
  - Não há pedido de "não rastrear" porque o app não rastreia.
