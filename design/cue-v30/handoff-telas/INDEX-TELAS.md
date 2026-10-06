# INDEX-TELAS · 55 telas em HTML

Cada arquivo é a tela **no estado final**, em 390 × 844 pt. Abra no navegador para ver as animações (CSS) rodando; o movimento detalhado está em `ANIMACOES.md` e `motion/screens-motion.json`. As telas do onboarding (1.x) e 8.3, 9.3 são as páginas originais (com seus scripts); as demais foram capturadas do protótipo já no estado indicado (os scripts foram removidos e o DOM ficou fixo). Estados de dados: APP DATA (Sample / New year / New account) e FREE EXPORTS (3 left / Last one / None left). `INDEX.html` mostra todas lado a lado.

| arquivo | como se chega | o que fazer nela |
|---|---|---|
| `1.1_welcome.html` | Primeiro uso, ao abrir o app | Get started → 1.2 · I already use Cue → Scripts |
| `1.2_topics.html` | 1.1 → Get started | Chips de tema (1–3), Continue → 1.3, Skip |
| `1.3_voyage.html` | 1.2 → Continue | Escolha de 1 plataforma, Head to {P} → 1.4 |
| `1.4_first-message.html` | 1.3 → Head to {P} | Load in teleprompter → 1.5 |
| `1.4b_slow-loading.html` | 1.4 quando a IA demora mais de 6 s | Use a ready-made message → 1.4 |
| `1.5_permissions.html` | 1.4 → Load in teleprompter | Continue → alertas do sistema → 1.6 |
| `1.6_practice.html` | 1.5 → Continue | Play central → contagem → leitura · Record it for real → gravador · Not now → Scripts |
| `1.7_first-star.html` | Depois do 1º take, Use take → 1.7 | Go to my studio · Edit this take first |
| `6.2_takes-from-planet.html` | 9.2 → toque no planeta → See in Takes › | Chip amarelo "{YEAR} · SHARED ✕" limpa o filtro |
| `6.3_continue-posting-card.html` | Fechar a fila no meio (✕) | Card "CONTINUE POSTING · 2 OF 3" → Continue |
| `6.3_last-free-export.html` | Takes → um vídeo · FREE EXPORTS › Last one | Rótulo "LAST FREE EXPORT · GO PRO" |
| `6.3_post-later.html` | Fila com "Post later" no LinkedIn | Rótulo "POST TO LINKEDIN LATER" |
| `8.1_explainer-2-networks.html` | Escolher 2 redes → Share to 2 networks (1ª e 2ª vez) | Start with TikTok |
| `8.1_last-free-export.html` | FREE EXPORTS › Last one | Medidor amarelo "LAST FREE EXPORT" |
| `8.1_network-app-cue-breadcrumb.html` | Queue → Send to {app} | Tela do app da rede (stand-in) com ◀ Cue |
| `8.1_pick-networks.html` | 8.1 → Share to universe | Redes (TikTok pré-marcado) · Also save to Photos · CTA |
| `8.1_posted-question.html` | Tocar ◀ Cue | Not yet · Yes, it's live |
| `8.1_queue-step.html` | Explicação → Start with TikTok | Checklist · aviso ◀ Cue · Send to {app} · Edit first · Post later |
| `8.1_save-video-share-icon.html` | Vídeo pronto → Share | Share to universe · Save video · ícone de compartilhar |
| `8.1_your-video-is-ready.html` | FREE EXPORTS › None left, tocar em Share | Sheet com Start free trial · See what's in Pro · Not now |
| `8.2_1-network.html` | Fila terminada com 1 rede "Yes" | Estrela voa até o planeta · +1 |
| `8.2_3-networks.html` | Fila terminada com 3 redes "Yes" | 3 estrelas, 350 ms entre elas · "SHARED TO 3 NETWORKS" |
| `8.3_milestone.html` | 25º vídeo do ano | Use Deep Space · Keep my current icon |
| `9.1_context-menu.html` | Toque longo (480 ms) no nome | Copy @handle · Share profile link · Edit profile |
| `9.1_default.html` | Tab Profile | Identity · Your universe · My Cue Voice · Plan |
| `9.1_edit-profile.html` | Edit (toolbar) ou toque na identidade | Cancel · Done |
| `9.1_new-account.html` | APP DATA › New account | Profile vazio, "5 OF 5 EXPORTS LEFT" |
| `9.2_live-2026.html` | 9.1 → Your universe (ou tab) | Planetas, marco, review, Share my 2026 universe |
| `9.2_new-account.html` | APP DATA › New account | Só o núcleo, "Record your first video" |
| `9.2_new-year.html` | APP DATA › New year | 2027 · 2026 · 2025, 2027 vazio |
| `9.2_planet-popover.html` | Tocar num planeta | See in Takes › → 6.2 filtrado |
| `9.2_sealed-2025.html` | Seletor de ano → 2025 | Selado: saturação .75, animações paradas |
| `9.2_share-sheet.html` | Share my 2026 universe | Image | 6 s video · Save to Photos · Share… |
| `9.2_year-in-review-first.html` | Your 2026 in review | Slide 1 de 5, 3,2 s cada |
| `9.2_year-in-review-last.html` | Review, avançar 4 toques | Slide 5, Share my 2026 |
| `9.3_my-cue-voice.html` | Settings ou Profile → My Cue Voice | Lista agrupada |
| `11.1_acknowledgements.html` | Settings › Acknowledgements | Navegação padrão do iOS (push/pop) |
| `11.1_app-icon.html` | Personalize › App icon | Navegação padrão do iOS (push/pop) |
| `11.1_font.html` | Prompter › Font | Navegação padrão do iOS (push/pop) |
| `11.1_language-region.html` | Settings › Language & Region | Navegação padrão do iOS (push/pop) |
| `11.1_menu-open.html` | Recording › Resolution (menu aberto) | Navegação padrão do iOS (push/pop) |
| `11.1_microphone.html` | Recording › Microphone | Navegação padrão do iOS (push/pop) |
| `11.1_permissions.html` | Privacy › Permissions | Navegação padrão do iOS (push/pop) |
| `11.1_personalize.html` | Settings › Personalize | Navegação padrão do iOS (push/pop) |
| `11.1_privacy-ai-data.html` | Settings › Privacy & AI data | Navegação padrão do iOS (push/pop) |
| `11.1_prompter.html` | Settings › Prompter (também o Aa do gravador) | Navegação padrão do iOS (push/pop) |
| `11.1_recording.html` | Settings › Recording | Navegação padrão do iOS (push/pop) |
| `11.1_remote.html` | Settings › Remote | Navegação padrão do iOS (push/pop) |
| `11.1_reset-confirm.html` | Privacy › Delete my Cue data (confirmationDialog) | Navegação padrão do iOS (push/pop) |
| `11.1_root.html` | Aba Settings · prévia no topo | Navegação padrão do iOS (push/pop) |
| `11.1_safe-zone.html` | Prompter › Social safe zone | Navegação padrão do iOS (push/pop) |
| `11.1_search-empty.html` | Busca sem resultado | Navegação padrão do iOS (push/pop) |
| `11.1_search-result.html` | Busca "font" na raiz | Navegação padrão do iOS (push/pop) |
| `11.4_pro-calm.html` | Sem exportações → Start free trial / See what's in Pro | Sem warp, "YOUR VIDEO IS READY" |
| `11.4_pro-final.html` | Profile › Plan, Settings › Cue Pro (estado final da abertura, após ~2,4 s) | Start 7-day free trial |
