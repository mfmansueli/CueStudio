# Memória de continuidade — copy do onboarding

A proposta de 12 de outubro de 2026 foi **implementada em 15 de outubro de 2026** (branch `copy/onboarding-voice-practice`), com o roteiro fixo e os
requisitos finais do dono, que prevalecem sobre a proposta onde diferem. O estado do app está em `DESIGN_PROJECT.md` §5.3, §18 e §35; este arquivo
guarda o texto aprovado e as decisões, para a próxima revisão.

## Decisões

- Teleprompter é a palavra que, segundo o dono, traz as buscas da App Store (premissa do dono, sem pesquisa de ASO).
- Telas, fluxo, universo visual, estrelas e animações ficam; muda o texto. Quem procurou um teleprompter entende logo: preparar o roteiro, ler olhando
  para a câmera, gravar no app, legendas automáticas, editar o take, compartilhar.
- **A prática sempre lê o roteiro fixo** (escolha do dono, 15/10/2026): a 1.4 mostra esse roteiro chegando no console, sem esperar a Apple
  Intelligence; a IA saiu do onboarding e o estado lento (1.4b) deixou de existir.
- A prática é leitura, não gravação: isso está na 1.4 ("It’s just practice. Nothing is recorded."), no chip da 1.6 e no cartão da 1.6.
- "follows my voice" só aparece enquanto o Voice Following por palavra funciona (ou está se preparando); sem microfone, ou num idioma que o iPhone
  não segue, a prática lê a versão sem essa frase e diz como o texto se move.
- Sem travessões (em dash) em copy nova. Nada promete publicar direto numa rede: o app prepara o vídeo e abre o compartilhamento.

## Roteiro fixo de prática (inglês; traduzido nos 20 idiomas do String Catalog)

- Título (como fica em Scripts): **From idea to video**
- HOOK: **An idea is good. Seeing it become a video is even better.**
- BODY (Voice Following por palavra): **Cue Studio helps me write it, read it with a teleprompter that follows my voice, and record it right here. I can
  add automatic captions and edit my take before sharing it.**
- BODY (sem Voice Following por palavra): **Cue Studio helps me write it, read it on a teleprompter, and record it right here. I can add automatic
  captions and edit my take before sharing it.**
- CTA: **My idea gets to sound like me and reach the people I made it for.**
- Duração mostrada: medida do texto a 150 palavras por minuto (`OnboardingScript.readingSeconds`): **24 SEC** em inglês (59 palavras), 22 s na versão
  sem a frase; cada idioma mostra o seu (alemão 25, japonês 29). O "15 SEC" do quadro saiu.

## Copy aplicada (inglês)

### 1.1 Welcome
- Título: Your words. Your voice. Your teleprompter.
- Apoio: Write your script, read it while you look at the camera, and record. Then add captions, edit, and share.
- Chips (sem mudança): TELEPROMPTER / AUTO CAPTIONS / ✦ AI SCRIPTS · Botões: Get started / I already use Cue

### 1.2 Topics
- CHAPTER 1 · YOUR TOPICS · What do you want to talk about?
- Pick up to 3. Cue uses them for your video ideas, and each one becomes a world.
- Contador, chips, "+ Your own", "Pick a topic" / "Continue": como o `09` §14 define (sem mudança).

### 1.3 Voyage
- CHAPTER 2 · YOUR FIRST VIDEO · Where will you share your videos?
- Cue sets the frame, the ideal length and the safe zones for that platform.
- CHOOSE ONE PLATFORM → {PLATFORM} · TAP ANOTHER TO SWITCH · linha: {aspecto} · IDEAL {faixa} · SAFE ZONES ON/OFF (OFF em YouTube e LinkedIn)
- Botão: Choose a platform → Continue with {platform}

### 1.4 First script
- CHAPTER 3 · YOUR FIRST SCRIPT · Your first script. Ready to read. · Read it out loud on the teleprompter.
- Cartão: ✦ PREPARING YOUR SCRIPT → ✦ PRACTICE SCRIPT · READY · VIDEO FOR · {PLATFORM} · {N} SEC · HOOK / BODY / CTA
- Cápsula: SCRIPT READY · LET’S TRY IT · nota: It’s just practice. Nothing is recorded. · Botão: **Try the teleprompter**

### 1.5 Permissions
- CHAPTER 4 · CAMERA & VOICE · Let the text follow your voice.
- The microphone lets the teleprompter follow your words, on this iPhone. The camera shows you while you read.
- Microphone · So the teleprompter follows your voice / Camera · So you can see yourself while you read · Allow / Next / ✓ Allowed / Off · Turn on
- Nota: Cue only records when you tap Record. · Recusas: microfone e câmera, só microfone, ou só câmera (três textos: o que muda na prática e onde ligar).

### 1.6 Practice
- Chip: ✦ PRACTICE · NOT RECORDING · TAP TO START · GET READY / 3 / 2 / 1 / READ!
- Cartão: Your teleprompter practice. + o que move o texto (Read out loud. The text waits, then follows your voice. / … moves while you talk. / …
  scrolls at a steady pace.) + We’ll count you in. Nothing is recorded.
- Estado sob a caixa: Getting ready to follow your voice · Getting Voice Following ready · 40% · Voice Following is on · Waiting for your voice ·
  Following your voice · Moves while you talk · Microphone off · Steady scroll
- Fim: You’ve got it. Ready to record? · Record this script for real, or start with your own.
- Botões: **Record my first video** / Explore Cue first · sem microfone: Turn on the microphone so the text can follow your voice. · Open Settings

### 1.7 First star
- FIRST VIDEO · FIRST STAR · Your first video. Your first star.
- Saved in Takes. Add captions, edit it or share it to light up your {year} universe.
- Botões: Explore Cue / Edit my video

## Retomada

Antes de mudar texto, ler `DESIGN_PROJECT.md` §35 e conferir cada promessa contra o app (IA, gravação, legendas, edição, compartilhamento, zonas
seguras, processamento no aparelho, permissões). As traduções foram feitas pelo modelo que construiu o app e pedem revisão de um falante nativo antes
do lançamento, principalmente o roteiro, que é lido em voz alta.
