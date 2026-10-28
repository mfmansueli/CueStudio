# Checkpoint PCC — 28/10/2026

Branch: codex/pcc-content-engines. Checkpoint solicitado pelo dono antes do fim do limite de tokens. Não é aprovação final de qualidade.

## Entrega preservada

Entitlement PCC habilitado no portal e confirmado no perfil e assinatura. Roteamento, deadlines, fallback, orçamento por rota e privacidade refinados. Exemplos brutos de voz e trechos importados ficam fora do PCC; preferências e fingerprint seguem. Automático decide a direção pelo pedido na própria geração; Talking head manual é preservado. Brief não promove placeholders a fatos. Proteção de frases explicitamente exigidas usa verificação e correção limitada, recusando resultado ainda inválido; não insere frase ausente. Último ajuste protege frases já presentes durante limpeza e normaliza NFC na comparação.

Pesquisa e fontes: Roteiros AI melhores no Cue.md e research_notes/Roteiros AI melhores no Cue/. Fixtures de prompts e saídas: Cue StudioTests/Fixtures/ScriptQuality/. Nada foi alterado no protótipo.

## Evidência e limites

16 saídas reais PCC arquivadas: seis baseline, dois controles de literal e oito casos protegidos. Rota privateCloud confirmada. Baseline: aproximadamente 2,3–4,1 s. Protegidos: aproximadamente 2,5–5,6 s; literal PT precisou de duas tentativas. Literais PT/EN/ES passaram na versão protegida. Qualidade geral NÃO aprovada: frases artificiais, passos pouco distintos, workshop/taller sem suporte no brief transmitido. Não prometer ausência de alucinações ou superioridade. Outros idiomas não validados fisicamente. Reasoning padrão não alterado; override é só para medição.

4.289 testes Fast passaram antes dos últimos refinamentos. Última rodada focada: 34 passaram, zero falhas (build/results/only-20261028-013110.xcresult), incluindo proteção literal, requisitos, voz e idioma. Outras rodadas focadas passaram; Python: seis verificadores de intenção e três de relatório. Catálogo sem traduções faltantes. Conferência limpa de warnings passou antes dos últimos ajustes e precisa ser repetida. Full final ainda pendente.

Contraste: capturas reais de simulador em build/pcc-captures e auditoria build/pcc-contrast-audit.txt, escala 3. Textos visíveis >=6,01:1; relatório também lista elementos cobertos/decorativos que não são texto visível.

## Aparelhos

iago Lima iphone: instalado e usado para testes PCC. Autorizado para automação. Teste UI PCCPrivacyUITests concluído: 1 passou, zero falhas; build/results/device-ui-20261028-013138.xcresult.

Mansuelli iPhone 18 Pro Max (00008160-0014398611100036): conectado na nova tentativa, build Debug concluído, app instalado e aberto com sucesso (com.cuestudioteleprompter). Disponível para testes manuais do dono e Mateus; manter automação no Iago. Comando usado:

```sh
CUE_DEVICE="Mansuelli iPhone 18 Pro Max" scripts/build.sh install
```

## Próxima sessão

1. Colher feedback dos testes manuais no Mansuelli; instalação e abertura concluídas. UI de privacidade no Iago passou.
2. Revalidar no Iago a última proteção de limpeza (34 testes locais passaram, execução física dessa última alteração ainda pendente).
3. Rever textos reais por fidelidade, fatos, voz, naturalidade, distinção dos pontos e CTA. Software passar não é aprovação editorial. Ampliar casos/idiomas progressivamente, marcando indisponíveis como não validados.
4. Quando não houver build ativo, rodar scripts/check-project.sh, scripts/check-warnings.sh e scripts/test.sh full. Não rodar check-warnings enquanto outro build usa o checkout: limpa intermediários antes do lock.
5. Registrar resultados e commit/push posteriores. Não fazer merge sem avaliar branch/base e validação.

Mudanças preexistentes excluídas do checkpoint: project.pbxproj (reordenação), 1465706025/, MARKETING_POSITIONING_MEMORY.md e reports/claude-code-auditoria-lacunas-e-validacao-2026-10-22.md. Não descartar nem incorporar automaticamente.
