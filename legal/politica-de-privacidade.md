# Política de Privacidade do Cue Studio

_Rascunho para o build de lançamento. Vigência: [DATA DA PUBLICAÇÃO]. Troque cada item [ENTRE COLCHETES] antes de publicar. Tradução da versão em
inglês (`privacy-policy.md`); as duas dizem o mesmo._

O Cue Studio ("Cue", "nós") é um app de iPhone e iPad para escrever, gravar, editar e compartilhar vídeos curtos. É feito por
[NOME DO DESENVOLVEDOR OU EMPRESA, como na App Store], responsável pelos seus dados. Contato: [E-MAIL DE SUPORTE].

Fizemos o Cue para que o que você cria fique no seu aparelho. Esta política explica as poucas coisas que saem dele, quem as recebe, por quê e
como interromper.

## 1. O que fica no seu aparelho

Seus roteiros, ideias (Logbook), gravações, edições, legendas, respostas e amostras de escrita do My Cue Voice, kits de marca, fontes e mídias
importadas e seu perfil (nome, @, foto) ficam só no seu aparelho. Não temos sistema de contas e não conseguimos vê-los.

Eles entram no backup do iCloud ou do computador, se você usa backup; esse backup é da Apple, sob a política de privacidade da Apple.

Processamento que acontece no aparelho e nunca chega a nós:

- **Reconhecimento de fala** do Voice Following, das legendas e da edição pelo texto (reconhecimento da Apple no aparelho).
- **Apple Intelligence** na escrita, nas ideias e nas ferramentas de edição. Alguns pedidos podem rodar no **Private Cloud Compute da Apple**,
  feito pela Apple para que seus dados não sejam guardados nem acessíveis à Apple; nós nunca os recebemos.
- **Vídeo e imagem**: recorte do fundo, suavização da pele, rastreio de rosto, áreas desfocadas, estabilização e exportações.
- **Traduções** de legendas (Translation da Apple).
- **Notificações e lembretes** são agendados no aparelho, sem servidor de push.
- **Controle remoto** entre os seus aparelhos usa uma conexão direta e criptografada na rede local, sem servidor no meio.

## 2. O que sai do aparelho, e por quê

### Ultra AI (só quando você escolhe)

A Ultra AI é uma roteirista opcional. Ela só roda se você permitir na tela de permissão e escolhê-la para um roteiro.

- **O que vai:** sua ideia como digitada (ou as respostas do formato), idioma, rede, formato e duração, suas preferências do My Cue Voice, a
  inspiração ou os dados de patrocínio que você pôs naquele pedido, e o rascunho entre as etapas. No "Fit to time" de um roteiro da Ultra AI,
  o roteiro com as suas edições. O texto exato aparece no app (Ajustes › Privacidade e dados de IA › O que a Ultra AI envia › Ver os pedidos,
  palavra por palavra).
- **O que nunca vai:** seu nome ou @, seus outros roteiros, amostras de escrita, trechos importados, vídeos, áudio ou fotos.
- **Quem recebe:** o pedido passa pelo servidor do Cue (Google Cloud Functions, operado por nós) e vai à **Anthropic, PBC**, que roda o modelo
  de IA e devolve o texto. Nosso servidor não guarda o texto. Pelos termos comerciais da Anthropic, ela não o usa para treinar seus modelos e
  pode guardá-lo por até 30 dias para detectar abuso ([termos comerciais da Anthropic](https://www.anthropic.com/legal/commercial-terms)).
- **Contagem dos roteiros:** para dar os roteiros grátis e os do Cue Pro, o app manda ao nosso servidor um **identificador aleatório criado
  para esta instalação** (sem ligação com seu nome, Apple ID ou contato), um identificador de cada roteiro em andamento e, se você assina o Cue
  Pro, o **registro assinado da compra na App Store**, para confirmar a assinatura. O servidor guarda só contagens (quantos roteiros, quando),
  sem texto. Elas são apagadas sozinhas cerca de **13 meses depois do último uso**.
- **Conferência de que o pedido vem do Cue:** cada pedido leva um token do **Firebase App Check** (Google), que usa o App Attest da Apple para
  confirmar que vem do app verdadeiro.
- **Como parar:** desligue a Ultra AI em Ajustes › Privacidade e dados de IA. Nada mais é enviado. Os roteiros que ela já escreveu ficam no
  aparelho.

### Convites (só quando você usa)

Se você pede seu código de convite ou digita o código de um amigo, o app manda ao servidor o mesmo identificador aleatório da instalação, o
código e, numa instalação convidada, que o primeiro vídeo foi exportado. O servidor guarda o código, a qual instalação pertence, quem entrou com
ele e as recompensas, para contar cada amigo uma vez. Nada de nomes, contatos ou mensagens: você mesmo envia o convite pela folha de
compartilhar do iOS.

### Ajudar a melhorar o Cue (opcional, desligado no início)

Se você liga **Ajudar a melhorar o Cue** (Ajustes › Privacidade e dados de IA), o app manda **dados de uso e relatórios de falha** ao **Google
Firebase** (Firebase Analytics e Crashlytics): telas e funções usadas, falhas, travamentos e medidas de desempenho, falhas da IA do aparelho ou
de exportações (com o modelo do aparelho, a versão do iOS e condições como memória livre) e o identificador de instalação do próprio Firebase.
Nunca inclui roteiros, ideias, gravações, nomes ou textos seus. O Cue não usa o identificador de publicidade e não rastreia você entre apps ou
sites. Desligue quando quiser; relatórios ainda não enviados são apagados.

### Compras

As assinaturas são da Apple. Não recebemos seus dados de pagamento. A Apple entrega ao app o registro da compra, que o app usa para liberar o
Cue Pro e, na Ultra AI, manda ao nosso servidor como descrito acima.

### O que você compartilha

Ao postar um vídeo, o app o entrega à folha de compartilhar do iOS ou ao app que você escolher (por exemplo, TikTok ou Instagram). Daí em
diante vale a política desse app. Salvar no Fotos pede ao iOS só a permissão de adicionar vídeos.

## 3. Permissões

O Cue pede câmera e microfone para gravar, reconhecimento de fala para o Voice Following e as legendas, Fotos (só adicionar) para salvar seus
vídeos, notificações para os lembretes que você marca e rede local para o controle remoto. Cada uma se muda nos Ajustes do iOS.

## 4. Bases legais (LGPD, GDPR e UK GDPR)

- **Execução do serviço que você pede:** os pedidos da Ultra AI e sua contagem, os convites, as compras.
- **Legítimo interesse:** impedir que os roteiros grátis e as recompensas de convite sejam usados mais de uma vez (o identificador aleatório e
  as contagens).
- **Consentimento:** Ajudar a melhorar o Cue (dados de uso e relatórios de falha) e a permissão da Ultra AI; você pode retirar qualquer um
  quando quiser, no app.

## 5. Onde os dados são tratados

Nosso servidor roda no Google Cloud, nos Estados Unidos (us-central1). A Anthropic e o Google tratam dados nos Estados Unidos e em outros
países, com suas cláusulas contratuais padrão.

## 6. Por quanto tempo

- No aparelho: até você apagar ou desinstalar o app.
- Contagens da Ultra AI no servidor: apagadas cerca de 13 meses depois do último uso.
- Texto dos pedidos da Ultra AI: não guardado pelo nosso servidor; guardado pela Anthropic por até 30 dias para detectar abuso.
- Registros de convite: enquanto o programa de convites existir; apagados a pedido (abaixo).
- Dados de uso e relatórios de falha (se você ligou): guardados pelo Google Firebase segundo a retenção do Firebase
  ([Analytics: 14 meses; Crashlytics: 90 dias]).

## 7. Apagar seus dados e seus direitos

- **No app:** Ajustes › Privacidade e dados de IA › **Apagar meus dados do Cue** apaga tudo o que o Cue guarda no aparelho (roteiros, ideias,
  gravações, edições, My Cue Voice, ajustes) e retira a permissão da Ultra AI, para que o Cue pergunte de novo antes de ela escrever outro
  roteiro.
- **O que não dá para recuperar:** pedidos da Ultra AI já enviados ficam com a Anthropic por até 30 dias, como acima. As contagens do servidor
  ficam sob um identificador aleatório, sem conteúdo, e expiram sozinhas.
- **No servidor:** para apagar antes seus registros de convite, escreva para [E-MAIL DE SUPORTE] com seu código de convite (aparece no app em
  Convidar amigos). Como não há conta nem nome, o código é como os encontramos.
- Você pode pedir acesso, correção, exclusão ou portabilidade dos seus dados, ou se opor ao tratamento, escrevendo para [E-MAIL DE SUPORTE].
  Também pode reclamar à autoridade de proteção de dados (no Brasil, a ANPD).

## 8. Crianças

O Cue não é dirigido a menores de 13 anos (ou da idade mínima do seu país), e não coletamos seus dados de propósito.

## 9. Mudanças

Se esta política mudar, atualizamos a data acima e, nas mudanças importantes, avisamos no app.

## 10. Contato

[NOME DO DESENVOLVEDOR OU EMPRESA] · [E-MAIL DE SUPORTE] · [ENDEREÇO, se quiser publicar]
