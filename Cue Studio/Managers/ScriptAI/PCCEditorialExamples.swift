import Foundation

/// Synthetic teaching examples, independent of any creator's private writing or tested prompts.
/// They demonstrate editorial reasoning rather than supplying facts for the requested video.
nonisolated enum PCCEditorialExamples {
    /// Activated only after the paired real-device evaluation demonstrates a useful gain.
    static let isEnabled = false
    static let instruction = """
    Learn the depth of reasoning from these synthetic examples. Their topics, details and sentences are NOT material for this video: never \
    copy them. Apply the method to the current request in the selected language and voice. The method is a position, a reason that explains \
    it, a concrete consequence or example, and a useful limit when relevant. Write connected speech, not these field names. Do not force a \
    limit or an example into a brief notice.

    Example of developing an opinion about preparing for a meeting:
    Position: Eu prefiro chegar com uma pergunta bem definida.
    Reasoning: Quando eu só digo que precisamos melhorar, cada pessoa pode imaginar um problema diferente. Uma pergunta específica dá um \
    ponto de partida comum e facilita entender o que precisa ser decidido.
    Concrete example: Eu trocaria “precisamos organizar melhor o trabalho” por “qual etapa está fazendo a entrega esperar?”. A resposta já \
    ajuda a escolher o próximo assunto, em vez de abrir várias conversas ao mesmo tempo.
    Useful limit: Numa reunião que apenas comunica uma decisão pronta, eu priorizaria explicar essa decisão. A pergunta precisa servir ao \
    objetivo da conversa.

    Example of developing one practical step about organizing recording files:
    Action: Eu daria ao arquivo um nome que identifica o assunto e a tomada.
    Reasoning: Um nome automático distingue arquivos, mas pode não dizer qual deles contém a cena que eu procuro. Um nome descritivo \
    permite reconhecer essa diferença antes de abrir cada vídeo.
    Concrete application: Eu usaria algo como “receita_abertura_take2”. Depois procuraria pela palavra “abertura” e abriria o resultado \
    para conferir se é a tomada esperada. Se vários arquivos ainda parecem iguais, acrescentaria a diferença que realmente ajuda a \
    escolher.
    Useful limit: Encontrar o arquivo com facilidade não cria uma cópia de segurança. Eu trataria o backup como outra tarefa.

    Example of comparing a backpack and a tote for carrying a laptop:
    I would choose the backpack for a longer walk because it leaves both hands free and keeps the load on both shoulders. That does not \
    guarantee comfort: I would still check the straps and how the bag fits. A tote gives me faster access when I keep taking a notebook \
    out on a short trip, but I carry its weight on one side. I would compare the same load on the same journey. The useful question is \
    how I carry and access these things, rather than which bag wins everywhere.

    Example of an explicitly fictional scene, not a claim about the creator's past:
    Estoy en la parada cuando aparece el autobús. Busco la tarjeta en un bolsillo, luego en el otro. El conductor abre la puerta y yo \
    sigo buscando, cada vez más despacio para fingir que todo está controlado. Entonces noto el borde de la tarjeta entre los dedos de \
    la mano con la que sostengo el teléfono. La acerco al lector, subo y guardo el móvil. Esta vez miro bien en qué bolsillo lo dejo.

    Follow the reasoning, not the wording or the example topics. Every paragraph should move the actual request forward. Keep room for the \
    creator to revise the draft.
    """
}
