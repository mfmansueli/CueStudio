# PROMPT · Claude Code

Implemente no app iOS (SwiftUI, iOS 27+, SDK do Xcode correspondente) as telas desta pasta, **com fidelidade total ao HTML e ao movimento**.

## Fontes (nesta ordem)
1. `screens/*.html`: a tela no estado final. Abra no navegador, inspecione. `INDEX.html` mostra todas; `INDEX-TELAS.md` diz como chegar em cada uma.
2. `ANIMACOES.md` + `motion/screens-motion.json`: **leia primeiro**. Todo o movimento, com motor Swift, receitas de efeito e as animações por código. Tela estática ou simplificada é erro.
3. `HANDOFF.md`: o que cada toque, gesto e toque longo faz, textos exatos, componente nativo do iOS por tela.
4. `docs/`: `09-Decisions.md` (vence em conflito), `07-Liquid-Glass.md`, `02-Tokens.md`, `10-Share-to-universe.md`, `03-Screen-map.md`, `04-Flows-and-states.md`, `strings-en.csv`, `motion/README.md`.

## Regras
- Não peça confirmação. Decida pelo documento e registre a decisão no relatório.
- Antes de criar componente ou tela, leia o código SwiftUI existente (`Cue Studio/DesignSystem`, `Cue Studio/Screens`) e reuse.
- Componentes nativos do iOS conforme `07-Liquid-Glass.md`; vidro simulado só quando não houver nativo. Cards de conteúdo não são vidro.
- Tipografia: interface SF Pro, sinais SF Mono; Geist dos HTMLs é só do protótipo. Marcadores: rede social = bolinha, tema = barra vertical de 3 pt.
- Reduzir Movimento / Low Power: quadro final, sem loops.
- Não toque em modo claro, no Studio (5.3) nem no "Reset Creator Setup" (mantenha a linha existente).
- Vídeos, hápticos e valores marcados como "proposta" nos documentos: use e liste no relatório.

## Fases
Fase 0 · Motor de movimento: `MotionPlayer` (decodifica o JSON, relógio único por tela com `TimelineView(.animation)`, avalia faixas) e os componentes de efeito (GlowDot, StarTrail, SparkBurst, ImpactRing, CrossFlare, RevealText, GalaxyCanvas com semente, CountIn). Teste com a 1.1 e entregue a gravação antes de seguir.
Fase 1 · Settings (11.1 e páginas): raiz com a prévia no topo, busca (com e sem resultado), Recording, Microphone, Prompter, Font, Social safe zone, Remote, Personalize, App icon, Language & Region, Privacy & AI data, Permissions, Acknowledgements, menu aberto, confirmação de reset.
Fase 2 · Your universe (9.2): 2026 vivo, 2025 selado, popover de planeta, Share my universe, Year in review, conta nova, ano novo.
Fase 3 · Profile (9.1): padrão, menu de contexto, Edit Profile, conta nova.
Fase 4 · Pro (11.4): abertura (warp, ignição, onda) e estado final; versão calma.
Fase 5 · Exportações grátis: 6.3 e 8.1 com "LAST FREE EXPORT", sheet "Your video is ready", contagem (5 grátis, 1 por envio, na entrega do arquivo).
Fase 6 · Share to universe (fase A, folha do iOS): redes, explicação, fila, ◀ Cue, "Posted?", card "Continue posting", 8.2 (1 e 3 redes), 6.3 "POST TO … LATER". Share Kit e Meta atrás de `shareKitEnabled = false`; teste no Sandbox durante o desenvolvimento.
Fase 7 · Telas ligadas: 8.3, 1.7, 9.3, 6.2 com filtro vindo do planeta.
Fase 8 · Onboarding 1.1 a 1.7 (inclui 1.4b): cada uma toca uma vez e para no quadro final.
Fase final · Relatório geral: o que foi feito, arquivos, decisões, desvios do HTML e pendências do dono do produto (por exemplo "Reset Creator Setup", ranking dos 10 temas, linhas de apoio por plataforma, hápticos propostos).

Ao fim de cada fase: compile, rode os testes, compare com o HTML, **grave a tela em movimento ao lado do HTML** e envie o relatório com a lista de diferenças antes de seguir.
