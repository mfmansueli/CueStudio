# Memória de continuidade — copy do onboarding

Conversa de 12 de outubro de 2026. O usuário gostou da proposta abaixo e pediu para preservá-la porque pretende retomar quando seus créditos voltarem em 18 de outubro. Nenhuma copy foi implementada no app; o próximo passo é retomar a revisão e, quando solicitado, aplicar as mudanças.

## Intenção e decisões

- Teleprompter é a principal palavra/função que, segundo o usuário, atrai buscas na App Store. Isso é uma premissa do usuário, não uma pesquisa de ASO realizada nesta conversa.
- Manter telas, fluxo, tema visual, universo, galáxias, estrelas e animações. Refinar o conteúdo dos textos para explicar a utilidade diretamente.
- Explicar primeiro: ler o roteiro enquanto grava, falar com mais confiança, preparar o vídeo para publicar. Apresentar AI scripts, captions e edit como benefícios adicionais.
- O texto conduz o primeiro uso concreto do teleprompter; o universo dá personalidade ao percurso.
- O usuário disse “eu gostei” da proposta. Isso não é uma solicitação para implementar agora.
- Não criar automação ou lembrete: não foram solicitados.

## Fontes e estado do repositório

- GitHub: mfmansueli/CueStudio; referências atualizadas com git fetch origin.
- Branch local observada: design/frontend-iterations; HEAD e8cdc0e6e91ab908359c7d6d9fb4a9af7acad30e.
- origin/main observado: b332eea (Merge pull request #36 from mfmansueli/feature/first-voyage).
- As oito telas HTML de onboarding locais estavam iguais às da main. Não houve merge/pull nem alteração do app nesta conversa.
- Diferenças observadas contra main no SwiftUI: MessageCard.swift e OnboardingWritingNotice.swift. Reavaliar o estado antes de implementar.
- Referência visual: design/cue-v30/handoff-telas/screens/1.x; ler LEIA-ME.md e docs/09-Decisions.md. Movimento em ANIMACOES.md.
- Copy atual foi coletada do código em Cue Studio/Screens/Onboarding, Cue Studio/Screens/Prompter/Practice e Cue Studio/Screens/TakeReview/Celebration/FirstStar, com conferência do catálogo de inglês.
- Ao implementar: seguir AGENTS.md, ARCHITECTURE.md, localização em 20 idiomas, contraste, testes e builds sem warnings. Atualizar DESIGN_PROJECT.md junto com a UI.

## Proposta de copy em inglês

Valores entre chaves são dinâmicos. Esta é a proposta apresentada e apreciada pelo usuário, não copy já aplicada.

### 1.1 Welcome

- Marca: CUE STUDIO
- Título: Your words. Your voice. Your teleprompter.
- Apoio: Read your script while you record. Write with AI, add captions, and edit—all in Cue.
- Chips: TELEPROMPTER / AUTO CAPTIONS / ✦ AI SCRIPTS
- Principal: Get started
- Secundário: I already use Cue

### 1.2 Topics

- Capítulo: CHAPTER 1 · YOUR TOPICS
- Título: What do you want to talk about?
- Apoio: Pick up to 3 topics for your first practice script. Watch your universe take shape.
- Universo: YOU / FIRST TAKE · TODAY
- Inicial: PICK UP TO 3 TOPICS
- Um tema: 1 OF 3 · CONTINUE OR PICK MORE
- Dois: 2 OF 3 · CONTINUE OR PICK ONE MORE
- Três: 3 OF 3 · TAP A TOPIC TO CHANGE
- Desabilitado: Pick a topic
- Habilitado: Continue
- Adicional: + Your own topic
- Navegação: Skip
- Temas mantidos, em ordem: Fitness & wellness; Food & cooking; Beauty & skincare; Fashion & style; Personal finance; Tech & AI; Budget travel; Productivity & career; Parenting & family; Morning routines.
- Tema próprio — título: Add your topic
- Placeholder: e.g. Budget travel
- Botões: Add topic / Cancel
- Validações: Enter a topic. / Use 40 characters or fewer. / Try another word for this topic. / You’ve already added this topic.
- Sugestão: Did you mean “{suggestion}”?
- Ações: Use suggestion / Keep mine

### 1.3 Voyage

- Capítulo: CHAPTER 2 · YOUR FIRST VIDEO
- Título: Where will you share your videos?
- Apoio: Choose your first destination. Cue sets the video format, target length, and framing guides.
- Centro: YOU
- Plataformas: TikTok / Reels / YouTube / Shorts / LinkedIn
- Antes: CHOOSE ONE PLATFORM
- Depois: {PLATFORM} SELECTED · TAP ANOTHER TO CHANGE
- Informação: {aspect ratio} · IDEAL {duration range} · SAFE ZONES {ON/OFF}
- Desabilitado: Choose a platform
- Habilitado: Continue with {platform}
- Navegação: Skip
- Nota para implementação: o código coletado sempre dizia SAFE ZONES ON; a proposta usa ON/OFF conforme o preset real. Conferir sem introduzir promessas incorretas.

### 1.4 First message

- Capítulo: CHAPTER 3 · YOUR FIRST SCRIPT
- Título: Your first script. Ready to read.
- Apoio: A short script about {topic}, made for your first teleprompter practice.
- Escrita: ✦ PREPARING YOUR SCRIPT
- Gerado pronto: ✦ READY FOR {PLATFORM} · 15 SEC
- Alternativa pronta: ✦ PRACTICE SCRIPT · READY
- Destino: VIDEO FOR · {PLATFORM}
- Duração: {seconds} SEC
- Seções: HOOK / BODY / CTA
- Confirmação: SCRIPT READY · LET’S TRY IT
- Privacidade: Your script is written on this iPhone.
- Principal: Try the teleprompter
- Navegação: Skip
- Aviso de IA, quando aplicável: Writing your script with Apple Intelligence / Processed on this iPhone.
- Roteiro fixo proposto — HOOK: Got something to share about {topic}? Start with one simple idea.
- BODY: You don’t need to memorize every word. Follow the text, look toward the camera, and speak at your own pace.
- CTA: That’s your first practice run. Now make it yours.
- Nota: verificar duração real do roteiro antes de fixar a promessa de 15 SEC; roteiro gerado pela IA varia.

### 1.4b Slow loading

- Mantém título e apoio da 1.4.
- Status: ✦ PREPARING YOUR SCRIPT
- Duração pendente: -- SEC
- Aviso: Your script needs a little more time.
- Apoio: You can still try the teleprompter with a practice script.
- Alternativa: Use a practice script
- Toast: Your practice script is ready
- Principal: Try the teleprompter

### 1.5 Permissions

- Capítulo: CHAPTER 4 · CAMERA & VOICE
- Título: Let the text follow your voice.
- Apoio: Enable your microphone for Voice Following and your camera to see yourself as you read.
- Ilustração: VOICE / CAMERA
- Microphone: Keeps the teleprompter in step with your voice
- Camera: Shows your camera preview while you read
- Estados/ações: Allow / Next / ✓ Allowed / Off / Enable
- Nota: Recording starts only when you tap Record.
- Negada: You can still practice with automatic scrolling. Enable permissions in Settings when you’re ready.
- Principal: Continue to practice
- Navegação: Skip

### 1.6 Practice

- Status: ✦ TELEPROMPTER PRACTICE · NOT RECORDING
- Inicial: Try your teleprompter.
- Instrução: Read the script out loud and follow the text.
- Apoio: We’ll count you in. Nothing is recorded.
- Antes: TAP TO PRACTICE
- Contagem: GET READY / 3 / 2 / 1 / LET’S READ!
- Final: You’ve got it. Ready to record?
- Apoio final: Use the teleprompter to record this script—or start with your own.
- Principal: Record my first video
- Secundário: Explore Cue first
- Microfone: Enable your microphone to let the text follow your voice.
- Ação: Open Settings
- O teleprompter usa o roteiro da 1.4.

### 1.7 First star

- Aparece depois do primeiro take real.
- Capítulo: FIRST VIDEO · FIRST STAR
- Status: ✓ VIDEO SAVED
- Título: Your first video. Your first star.
- Apoio: Your video is saved in Takes. Add captions, edit, or share it to light up your {year} universe.
- Universo: FIRST TAKE · TODAY
- Principal: Explore Cue
- Secundário: Edit my video

## Retomada

Ler este arquivo e perguntar/seguir o próximo refinamento solicitado. Não presumir que o usuário pediu implementação. Ao aplicar, conferir compatibilidade das promessas com o comportamento real, comprimento/layout dos textos e estados de permissões/IA.
