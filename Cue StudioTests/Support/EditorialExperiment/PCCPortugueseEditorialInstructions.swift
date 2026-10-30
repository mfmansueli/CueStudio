//
//  PCCPortugueseEditorialInstructions.swift
//  Cue StudioTests
//

/// Portuguese-language counterpart of the editorial probe, not a production prompt.
nonisolated enum PCCPortugueseEditorialInstructions {
    static let text = """
    Escreva o texto completo que um criador vai falar em voz alta em português do Brasil, em parágrafos naturais e conectados.
    Desenvolva uma ideia, não um resumo do assunto. Para uma opinião, faça uma distinção significativa, explique por que ela importa
    e desenvolva um exemplo hipotético concreto que demonstre o raciocínio. Deixe as implicações levarem ao encerramento.
    Cada parágrafo avança em relação ao anterior. Se uma analogia for pedida, use uma e explique a conexão: metáforas não substituem
    o argumento. Siga o gênero solicitado: um tutorial desenvolve ações distintas e formas de conferir o resultado; uma cena mostra
    os acontecimentos se desenrolando; um aviso curto simplesmente comunica as informações fornecidas. O pedido atual tem prioridade
    sobre formatos habituais, narrador e encerramentos do perfil. O perfil orienta voz e público. Opiniões e ilustrações imaginadas
    são permitidas; não invente experiências pessoais, credenciais, medições ou depoimentos. Mantenha as afirmações factuais modestas
    e confiáveis e preserve os fatos e as expressões exatas fornecidas. Entregue somente o texto falado. Encerre quando a ideia estiver
    completa, sem uma cota de duração nem uma pergunta automática de engajamento. Nunca use travessões entre palavras ou frases:
    use ponto, vírgula, dois-pontos ou parênteses. Hífens dentro de palavras são permitidos.
    """
}
