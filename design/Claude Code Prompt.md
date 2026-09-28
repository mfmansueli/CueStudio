# Prompt para o Claude Code — Cue Teleprompter: V1 → V7

> Copie tudo abaixo da linha e cole no Claude Code, na raiz do repositório do app.
> Antes, coloque o arquivo de referência `Cue Teleprompter v7.dc.html` em `design/` no repositório.

---

Você vai evoluir o app iOS **Cue** (teleprompter para criadores de conteúdo) da versão atual (V1) para a versão de design V7.

## Referência de design
- A fonte da verdade visual e de comportamento é `design/Cue Teleprompter v7.dc.html`, um protótipo HTML interativo.
  - O template (markup) mostra o layout, os estilos e o texto de cada tela.
  - A classe `Component` no `<script>` mostra os estados, as regras e os dados de exemplo.
- Leia esse arquivo inteiro antes de começar. Quando este prompt e o protótipo divergirem, siga o protótipo e me avise.
- O protótipo usa um painel lateral de "flows" apenas para navegação da demo. Não implemente esse painel.

## Regras de trabalho
1. **Explore o código primeiro.** Mapeie a arquitetura atual (SwiftUI/UIKit, navegação, persistência, câmera, teleprompter) e me mostre um plano curto antes de alterar qualquer coisa.
2. **Trabalhe por fases** (abaixo), uma de cada vez. Ao fim de cada fase: compile, rode os testes, faça um commit e me mostre um resumo curto.
3. **Não quebre o que funciona:** gravação, rolagem do teleprompter e roteiros já salvos devem continuar funcionando. Se precisar migrar dados, escreva a migração.
4. Use **apenas frameworks da Apple**, sem SDKs de IA de terceiros e sem backend próprio: o objetivo é custo operacional zero.
5. Interface **nativa iOS**, somente tema escuro: sheets com detents, context menus, swipe actions, SF Symbols, Dynamic Type onde couber, alvos de toque de no mínimo 44 pt.
6. Centralize os tokens abaixo num único arquivo de tema e nunca espalhe cores soltas pelo código.
7. Se algo aqui depender de uma API que você não conseguir confirmar no SDK instalado, **pare e me pergunte**. Não invente API.

## Tokens de design
- **Cores base**
  - Fundos: `#000000` (tela), `#1C1C1E` (cards/sheets), `#2C2C2E` (linhas/controles), `#3A3A3C`, `#636366` (segmento selecionado)
  - Texto: branco, secundário `rgba(235,235,245,0.6)`, terciário `rgba(235,235,245,0.3)`
  - Separadores: `rgba(84,84,88,0.6)`, com 0.5 pt
  - Acento: **amarelo `#FFD60A`** (ações primárias, estados ativos, IA)
  - Gravar: **`#FF3B30`**
  - Sucesso `#34C759`, aviso `#FF9F0A`, destrutivo `#FF453A`, info/versões `#64D2FF`
- **Cores das plataformas:** TikTok `#64D2FF` · Reels `#BF5AF2` · Shorts `#FF6961` · YouTube `#FF9F0A` · LinkedIn `#0A84FF` · Stories `#FF375F`
- **Raios:** cards 26 pt · sheets 38 pt · botões pill = altura/2 · chips 15–17 pt
- **Tipografia:** SF Pro na interface. No teleprompter, as opções de fonte são Lexend, Atkinson Hyperlegible, Source Serif 4 e SF Rounded; empacote as fontes com o app.
- **Superfícies de vidro** (barra inferior, toolbar da câmera): material blur + borda de 0.5 pt `rgba(255,255,255,0.12)`

---

## Fase 1 — Navegação
- **Tab bar flutuante em pill** com 4 itens: **Scripts · Takes · Profile · Record**. O Record faz parte da barra: ícone de círculo com ponto vermelho e rótulo "Record".
- **"+" no topo da tela Scripts** abre a sheet **New script**:
  - Caixa em destaque **Prompt** (fundo amarelo suave, selo "Apple Intelligence", campo de exemplo e botão enviar), que abre Generate › Prompt.
  - Grade 2×2 abaixo: **Write**, **Import**, **Themes**, **Formats**.
- **Record** abre a sheet **Start recording**:
  - Lista "Read from a script" (4 roteiros recentes com duração estimada).
  - Linha "+ New script".
  - Botão secundário **"Record without a script →"** com a nota "Freestyle now — add a script anytime from the camera."
- **Estado vazio da tela Scripts:** título, caixa Prompt em destaque, lista Write / Import / Generate with AI e o botão "Record without a script".

## Fase 2 — Roteiros: ler × editar (padrão Apple)
- **Tocar num roteiro abre a leitura (somente leitura):**
  - Título, chip da plataforma (abre Create for), chip do formato e resumo do preset.
  - Barra de duração e faixa de blocos.
  - Texto formatado com rótulos de bloco (HOOK, BODY, CTA…).
  - Takes do roteiro e botões fixos **Studio mode** e **Record**.
  - Botão principal: **Record** (amarelo). Em roteiros de YouTube, o principal passa a ser **Studio**.
- **Entrar em edição:** botão **Edit** no topo, ou dois toques no texto. O editor tem Cancel/Done, título editável, chips de metadados, faixa de blocos, texto cru com marcações `[pause]`, `[smile]`, `[emphasis]`, `[confident]`, `[look at camera]` etc., atalhos de IA e a barra de duração.
- **Versões:** editar um roteiro que já tem takes cria `v(n+1)`, e as takes anteriores continuam ligadas à versão antiga. No editor, mostre o aviso "Editing creates v2 · your 3 takes stay linked to v1".
- **Na lista:**
  - Pressionar e segurar abre o context menu com prévia: Record, Studio mode, Edit | Duplicate, Move to folder, Share | Delete (destrutivo).
  - Deslizar à direita = Record; deslizar à esquerda = More / Delete.
  - "Select" no cabeçalho ativa a seleção múltipla, com barra de ações Move / Duplicate / Delete.
- **Faixa de blocos:** cada bloco mostra o tempo estimado (150 palavras por minuto × velocidade). Se o Hook passar de 3,5 s, ele fica laranja com o aviso "Hook runs ~Xs — aim for 3s", e tocar nele abre "Pick a new hook".

## Fase 3 — "Create for" (presets por plataforma)
Cada roteiro tem uma plataforma. Ao escolher, aplique o preset automaticamente e mostre o toast "Create for {plataforma}".

| Plataforma | Formato | Qualidade | Duração ideal | Mínimo (com monetização) | Layout do prompter |
|---|---|---|---|---|---|
| TikTok | 9:16 | 1080p30 | 60–90 s | 60 s | topo 118, altura 280, largura 58% |
| Reels | 9:16 | 1080p30 | 15–60 s | — | topo 104, altura 290, largura 60% |
| Shorts | 9:16 | 1080p60 | 30–60 s | — | topo 104, altura 262, largura 60% |
| YouTube (longo) | 16:9 | 4K24 | 8–15 min | 8 min | faixa preta acima do vídeo, largura 70% |
| LinkedIn | 4:5 | 1080p30 | 30–90 s | — | topo 196, altura 240, largura 64% |
| Stories | 9:16 | 1080p30 | 8–15 s | — | topo 150, altura 264, largura 56% |

- **Monetização:** o toggle "Monetization goals" (ligado por padrão) ativa os mínimos. Sem ele, TikTok ideal = 15–60 s e YouTube = 4–10 min.
- **Zonas seguras:** retângulos tracejados discretos por plataforma, com as coordenadas exatas em `layout()` no protótipo (ex.: "TIKTOK BUTTONS", "CAPTION · TIKTOK UI", "REPLY BAR · STORIES UI"). O YouTube não tem zonas.
- **Barra de duração:** preenchimento + faixa ideal em amarelo translúcido + marca branca no mínimo ("1:00 · monetizes" / "8:00 · mid-rolls"). O status à direita pode ser "16s to monetize", "In the ideal range" ou "12s over ideal".
- **Regras de monetização como configuração remota:** carregue os limites de um JSON (bundle + atualização opcional), porque as regras das plataformas mudam.

## Fase 4 — IA com Apple Intelligence (somente)
Use **apenas** a Apple Intelligence:
- **Framework Foundation Models:** `LanguageModelSession`, `instructions`, guided generation com `@Generable`/`@Guide`.
- **Private Cloud Compute**, pela mesma API do framework, se disponível no SDK instalado.
- **Speech** para transcrição, **Vision** para OCR, **Writing Tools** do sistema e **App Intents**.

**Estratégia de modelo (custo zero):**
- **No aparelho:** reescritas, tom, ganchos, CTA, "Fit to time", "In my voice" e sugestões de tema. É rápido e funciona offline.
- **Private Cloud Compute:** prompt livre e temas factuais (história, ciência, "como surgiu…"). Se o PCC não estiver disponível no SDK, use o modelo do aparelho e mantenha o aviso.

**Aviso de fatos (obrigatório):**
- Na aba Prompt, fixo: *"AI can get facts wrong. Topics like history or science are written with Apple’s Private Cloud Compute — check dates, names and numbers before you record."*
- Roteiros gerados sobre temas factuais recebem `factCheck = true` e mostram um banner laranja no topo da leitura, com o botão "Checked" para dispensar.

**Disponibilidade:** verifique a disponibilidade do modelo (`SystemLanguageModel.default.availability` ou o equivalente no SDK):
- Se não disponível, os recursos de IA aparecem desativados com explicação ("Requires Apple Intelligence").
- O teleprompter continua 100% funcional.

**Sheet Generate with AI:**
- **Cabeçalho:** "Generate with AI · Apple Intelligence · private · no cost". Três abas: **Prompt · Themes · Formats**.
- **Prompt:**
  - Textarea livre e chips de exemplo (ex.: "2 minutes on how the electric shower was invented in Brazil").
  - Linhas Create for (TikTok, Reels, Shorts, YouTube, LinkedIn) e Length (Auto, 30s, 1 min, 2 min, 3 min). 2 min ≈ 300 palavras.
  - Toggle "Write in my voice", o aviso de fatos e o botão "Generate script".
- **Themes:** 6 ideias baseadas no nicho do Creator Voice (lista local por nicho em `THEMES` no protótipo), cada uma com tipo e duração, e o botão "New ideas". Tocar numa ideia preenche a aba Prompt.
- **Formats:** 8 formatos — Sponsored ad (**PRO**), Review, Tutorial, Tips/list, Storytime, Hot take/reply, Announcement, Apology/statement.
  - Cada formato tem estrutura de blocos, campos com placeholders, dica de escrita, tons e atalhos próprios. Tudo está em `static TYPES` no protótipo; porte essa tabela.
  - O **Apology/statement** é modo sério: sem gancho, humor, hype ou CTA.
- **Saída estruturada:** gere os roteiros com guided generation, num struct `@Generable` com `title` e uma lista de `blocks` (`label`, `text`), mais as marcações de performance.
- **Creator Voice nas `instructions`:** frases, tom, vocabulário, estilo e nicho vão em toda sessão quando "Write in my voice" estiver ligado.

**Atalhos de IA no editor** (variam por formato): "In my voice", "3 new hooks", "Fit to time", "More energy", "Fix grammar", "Translate". Na publi, entram também "Stronger CTA" e "Add disclosure". No pedido de desculpas: "More human", "Less defensive", "Shorter & direct".

**Outros recursos da Apple:**
- **Import por foto** com Vision OCR (fotografar um briefing impresso).
- **Writing Tools** habilitado no editor.
- **App Intents:** "Record script {nome}" e "New script".

## Fase 5 — Teleprompter (Selfie)
- **Câmera em primeiro plano:**
  - Painel de texto flutuante com largura padrão de 60% (ajustável entre 50% e 75%) e fundo com 25% de opacidade.
  - Sombra leve no texto para legibilidade.
  - A posição e a altura do painel vêm do preset da plataforma.
- **Topo:** fechar, segmento **Selfie | Studio** e o chip "{Plataforma} · 9:16", que abre Create for.
  - Durante a gravação, aparece a pill vermelha "● 00:42 | 18s to 1:00", ou "✓ Monetizable" quando o mínimo é atingido.
- **Veja a Fase 5B para a geometria, as zonas seguras, a Reading Line, a velocidade e o Hide UI — ela prevalece sobre qualquer valor desta fase.**
- **Toolbar inferior** (vidro):
  1. Segmento **Voice Following | Steady**.
  2. Controles do roteiro:
     - No Steady: velocidade − / 1.0× / +.
     - No Voice Following: indicador de onda "Listening/Paused".
     - Sempre: voltar ao topo, play/pause e **Aa** (Display).
  3. Controles de câmera: última take, ajustes de câmera, botão gravar, virar câmera e timer.
- **Voice Following:** use `Speech` no aparelho para acompanhar a fala e rolar o texto até a palavra atual. Quando a fala pausa, a rolagem espera.
- **Aviso ao parar antes do mínimo:** card com "18s short of 1:00" + explicação da regra da plataforma, e os botões "Stop anyway" / **"Keep going"**.
- **AI Coach** (toggle no Display): mostra ou esconde as marcações de performance. Elas ficam discretas (caixa-alta, 0.42 em, amarelo translúcido), com o texto falado em destaque.
- **Sem roteiro (Freestyle):** a linha do roteiro vira "Freestyle — No script, add one anytime" + botão "Add script".

**Sheet Display:**
- Detents média e máxima. A máxima **nunca cobre a área de leitura**: a borda de cima da sheet para exatamente onde o painel de texto termina. Arrastar para baixo fecha.
- **Prévia ao vivo** (selo verde "Live preview").
- **Quick:** AI Coach, Text size, Reading width, Reading line (Top/Bottom), Background opacity, Camera blur (Off/Low/Medium/High).
  - Nota: *"Background and blur only change your preview — never the recording."*
- **Advanced** (recolhível): fonte, espaçamento entre linhas, margens, alinhamento, cor do texto, mostrar linha de leitura, espelhar texto.
- **No Studio**, esconda largura, opacidade e desfoque, e mostre a cor de fundo.

**Ajustes de câmera** (sheet com abas Camera | Recording):
- **Camera:** lente, formato, resolução, fps, grade, estabilização, zonas seguras.
- **Recording:** microfone, contagem regressiva, iniciar rolagem com a gravação, parar quando o roteiro acabar, salvar no Fotos, HEVC/H.264.

## Fase 5B — Arquitetura da tela de gravação (CRÍTICO — faça antes de mexer no visual da Fase 5)

**Antes de codificar, investigue e me reporte:**
1. Como o preview da câmera é implementado (AVCaptureVideoPreviewLayer? videoGravity?).
2. Como o frame de gravação é definido (sessionPreset, formato, crop).
3. Como os overlays são posicionados hoje.
4. Como o teleprompter é renderizado e rolado.
5. Onde a velocidade é controlada.
6. Como o vídeo final é exportado.

Depois disso, proponha a lista de arquivos a mudar e só então implemente, de forma incremental, **sem reescrever o que já funciona**.

### Regra 1 — Vídeo ≠ interface
- O vídeo gravado é um canvas independente: **9:16 = 1080×1920** (4:5 = 1080×1350, 16:9 = 1920×1080).
- Os controles, as zonas seguras, a linha de leitura e a caixa de texto são **camadas de interface sobre o preview**. Eles **nunca** aparecem no arquivo e **nunca** mudam a geometria do vídeo.
- O painel inferior pode cobrir parte do vídeo. Isso não significa que o vídeo termina acima do painel.
- O iPhone é mais alto que 9:16. O preview deve mostrar **exatamente** o frame gravado: calcule o retângulo do frame na tela (largura total e altura = largura × 16/9) e escureça (~60%) a área fora dele. Não use `resizeAspectFill` em tela cheia fingindo que aquilo é o vídeo.

### Regra 2 — Dois sistemas de coordenadas
- **VideoSpace:** 0…1080 × 0…1920. Nele vivem as zonas seguras.
- **ScreenSpace:** depende do iPhone, da Dynamic Island/notch, das safe areas e da orientação. Nele vivem os controles, a linha de leitura e a caixa de texto.
- Crie um único conversor, por exemplo `struct FrameGeometry { let videoSize: CGSize; let frameRectOnScreen: CGRect; func toScreen(_ r: CGRect) -> CGRect }`, derivado do layer de preview real, e use-o em todos os overlays.
- **Nada de posições fixas** baseadas num modelo de iPhone.

### Regra 3 — Social Safe Zones (configuração atualizável)
```swift
struct SocialSafeZonePreset: Codable {
  let platform: String          // "reels", "tiktok", "shorts", "stories", "linkedin"
  let aspectRatio: String       // "9:16"
  let videoSize: CGSize         // 1080×1920
  let topRisk, bottomRisk, leftRisk, rightRisk: CGFloat   // px em VideoSpace
  var recommendedContentRect: CGRect { /* derivado das margens */ }
}
```
- **Valores iniciais** (px em 1080×1920; LinkedIn em 1080×1350):
  - Reels 220 / 420 / 60 / 120
  - TikTok 160 / 480 / 60 / 140
  - Shorts 190 / 380 / 60 / 140
  - Stories 250 / 250 / 60 / 60
  - LinkedIn 4:5 0 / 200 / 40 / 40
  - (ordem: topo / base / esquerda / direita)
- **Custom:** margens do usuário em %, persistidas.
- **Carregamento:** um JSON no bundle + atualização remota opcional (as plataformas mudam de interface).
- **Aviso:** deixe explícito no código e na interface que a zona é **orientação visual, não garantia**.
- **Visual discreto:**
  - faixas de risco com degradê suave (topo e base) e sombra leve nas laterais;
  - a borda da área segura em linha tracejada fina, com uma legenda pequena ("INSTAGRAM REELS SAFE AREA");
  - nada de caixas sólidas.

### Regra 4 — Reading Line (camada própria, fixa)
- **A linha fica parada e o texto passa por ela.** A linha nunca segue o texto.
- **Posição padrão** relativa à **lente física**:
  - câmera frontal: logo abaixo da lente (no protótipo, 118 pt abaixo, respeitando a barra superior);
  - câmera traseira: por volta de 36% da altura do frame;
  - no Studio não há câmera.
- **Ajuste:** o usuário arrasta a linha verticalmente pela alça (alvo de 44 pt) ou usa ↑/↓ nos ajustes, e tem **Reset**. A posição é guardada como distância da lente, para funcionar em qualquer iPhone.
- **Primeira vez:** mostre a dica "Don't read the text. Talk to the line.", que some ao tocar ou ao dar play.

### Regra 5 — Text Window (camada própria)
- **Altura** de 160 a 380 pt (padrão 250) e **largura** de 50 a 75% (padrão 60%, controlada para evitar movimento horizontal dos olhos).
- **A linha fica sempre dentro da janela**, por volta de 25% do topo, com as próximas frases aparecendo abaixo. Se a linha for movida, a janela acompanha. São duas camadas com estados separados, e a relação é só uma restrição de layout.
- **O padding** do conteúdo é calculado para que a linha atual fique centrada na Reading Line.

### Regra 6 — Velocidade
- **Remova −/valor/+.** No Selfie, use um slider horizontal compacto com o valor ao lado ("0.7×"), de 0.3 a 2.0 em passos de 0.1.
- **Padrão 0.7×.** Recalibre a escala para 1.0× = 215 palavras por minuto, de modo que 0.7× ≈ 150 wpm (ritmo natural). A estimativa de duração dos roteiros usa a mesma constante.
- **Steady** mostra o slider. **Voice Following** mostra "AUTO" com o indicador de voz, e o slider fica oculto.

### Regra 7 — Hide UI durante a gravação
- Um botão de olho no topo, visível só durante a gravação, esconde a toolbar, as zonas seguras, o chip de plataforma e os ajustes.
- **Continuam visíveis:** texto, Reading Line, cronômetro e um botão de parar mínimo.
- **Opção "Hide controls while recording":** esconde automaticamente ao começar a gravar.
- Ao parar a gravação, a interface volta.

### Regra 8 — Painel de ajustes (Display › Layout)
- Reading line ↕ (posição) · Text window ↕ altura / ↔ largura · Speed
- **Social safe zone:** Reels / TikTok / Shorts / Stories / Custom (4:5 mostra LinkedIn / Custom), mais Show / Hide.
- "Hide controls while recording" e **Reset to Recommended**.
- **A folha de ajustes nunca cobre a Text Window.**

### Regra 9 — Experiência padrão
- Frame 9:16, com Reels quando não há roteiro (com roteiro, vale a plataforma dele).
- Linha e janela já posicionadas, velocidade 0.7× e zona segura visível e discreta.
- Dá para gravar sem configurar nada.

### Critérios de aceite
- O arquivo exportado é sempre o frame completo, sem nenhum overlay (inclua um teste).
- As zonas seguras ficam corretas em iPhone SE, 15, 16 Pro Max e em iPad no modo compatível.
- A linha de leitura continua na mesma distância da lente após rotação e troca de aparelho.
- Os testes unitários cobrem: conversão VideoSpace → ScreenSpace, presets, restrição linha ↔ janela e calibração de velocidade (wpm).

## Fase 6 — Studio mode
- Tela cheia sem câmera, com barra de progresso no topo e o botão espelhar.
- Toolbar: o mesmo segmento Voice Following | Steady, velocidade (slider) ou indicador de voz, voltar ao topo, parágrafo anterior/próximo, play grande amarelo e Aa.

## Fase 7 — Takes
- **Modelo `Take`:** `id, scriptId?, number, duration, createdAt, isBest, isEdited, isExported, aspect, resolution, platform, fileURL, scriptVersion`.
- **Biblioteca (aba Takes):**
  - Filtros por plataforma (All, TikTok, Reels, Shorts, YouTube, LinkedIn) e por visão (All takes, ★ Best, Not shared, Edited).
  - Seções Today / Yesterday / Earlier.
  - Cada linha é **um vídeo** (takes agrupadas por roteiro): miniatura no formato correto, duração, plataforma, formato, resolução, data e chips "3 takes · Best: Take 3", "Edited", "Not shared".
- **Revisão da take:**
  - Prévia no formato da take, com barras pretas se não for 9:16.
  - Topo: voltar, "Take N · 0:44", **estrela** e **lixeira**.
  - Faixa **"Your takes · N"** para alternar entre takes do mesmo roteiro.
  - Ações **Edit · Retake · Save · Share**, com Share em amarelo.
  - Só uma take por roteiro pode ser a melhor.

## Fase 8 — Quick edit
- Cancel / "Quick edit 1:04 → 0:58" / Done. Prévia ao vivo e barra de ferramentas com 6 itens:
  - **Trim:** alças amarelas, playhead, Split no playhead, Delete da seção selecionada, "Remove silences" (detectar silêncios com análise de áudio).
  - **Audio:** volume de 0 a 150%, "Enhance voice", "Reduce background noise".
  - **Adjust:** exposição, contraste e temperatura (−100 a +100), com botão Auto.
  - **Filters:** Original, Vivid, Warm, Cool, Mono, Film.
  - **Crop:** 9:16, 4:5, 1:1, 16:9, arrastar para reposicionar e Reset.
  - **Captions:** gerar a partir do roteiro, sincronizadas com a transcrição do `Speech`, em 3 estilos (Classic, Bold, Highlight) e 3 posições.
- Implemente com **AVFoundation** (`AVMutableComposition`, `AVVideoComposition` com Core Image), sem destruir o original.
- Done salva a nova duração e marca a take como Edited.

## Fase 9 — Share to
- **Cabeçalho:** miniatura, "Share to" e título.
- **Grade:** TikTok, Reels, Shorts, YouTube, LinkedIn, Stories, Save video e More. A plataforma de origem fica destacada com anel amarelo, e a nota diz "Created for {X} — framed and safe-zoned for it".
- **Opções:** "Burn in captions" e Quality (1080p/4K).
- No plano grátis, mostre o contador de exportações sem marca d'água.
- Os destinos abrem o app correspondente, ou o `UIActivityViewController` como fallback.

## Fase 10 — Profile
- **Conta:** avatar, nome, @, "Signed in with Apple" e selo FREE/PRO. Implemente **Sign in with Apple** como único login.
- **Creator Voice:**
  - Card "Sounds like you" com prévia ao vivo e o toggle "Use my voice in AI scripts".
  - How I sound (multi: Casual, Energetic, Professional, Funny, Educational, Confident).
  - My phrases (adicionar/remover).
  - My vocabulary (Simple, Technical, Gen Z, Professional).
  - My style (multi: Short sentences, Storytelling, Educational, Opinion-driven, Conversational).
  - Niche (multi).
  - É um perfil único, válido para todas as redes.
- **Plano:** no grátis, medidor "Clean exports x of 5", a linha "Apple Intelligence · On-device · unlimited" e o botão "Try Pro free for 7 days". No Pro, o plano atual e "Manage".
- **Settings:** Default "Create for", Monetization goals, Privacy & AI data, Restore purchases, Sign out.

## Fase 11 — Monetização (StoreKit 2)
- **Grátis:**
  - Teleprompter completo (Selfie e Studio) e roteiros ilimitados.
  - IA com Prompt, Themes e os formatos básicos.
  - **5 exportações sem marca d'água**; depois, exportação ilimitada **com marca d'água discreta "Made with Cue"**.
  - As takes nunca são bloqueadas e podem ser reexportadas sem marca depois de assinar.
- **Pro:** exportação sem marca d'água até 4K, Creator Voice completo, Sponsored ad, variações de gancho, versões multiplataforma, sugestão de melhor take, controle remoto via Apple Watch e sincronização iPad/Mac.
- **Produtos:** `pro.monthly` US$ 7,99 · `pro.annual` US$ 39,99 com 7 dias grátis (pré-selecionado, selo "SAVE 58%") · `pro.lifetime` US$ 89,99 (não consumível).
  - Preços regionais sugeridos no Brasil: R$ 24,90 / R$ 119,90 / R$ 299,90.
- **Paywall** em tela cheia, com título contextual:
  - Exportar: "Post without the watermark", com a comparação com/sem marca e o link "Save with watermark instead".
  - Formato PRO: "Brand deals, done right".
  - Profile: "Create more. Sound like you."
  - Rodapé: Restore, Terms, Privacy.
  - Nunca mostre o paywall durante uma gravação.

## Fora do escopo agora
- Onboarding com Creator DNA no primeiro acesso.
- Projetos/pastas avançados. Mantenha apenas "Move to folder" simples, se já existir.
- Tendências em tempo real, que exigiriam backend.

## Entrega final
- Um resumo por fase: o que mudou, arquivos principais e pendências.
- Testes unitários para: estimativa de duração e zonas, presets por plataforma, regras de exportação grátis/pro, versões de roteiro e seleção de melhor take.
- Uma lista de tudo que ficou diferente do protótipo e por quê.
