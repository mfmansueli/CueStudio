//
//  PCCEditorialDemonstration.swift
//  Cue StudioTests
//

import FoundationModels

/// One complete synthetic demonstration on a topic outside the frozen video-writing cases. Never the evaluated case's answer.
nonisolated enum PCCEditorialDemonstration {
    static let request = "Defenda que comprar mais caixas nem sempre ajuda a organizar a casa. Desenvolva um exemplo hipotético e uma conclusão útil."
    static let response = """
    Eu não começaria a organização comprando mais caixas. Primeiro, eu tentaria entender por que as coisas ficaram espalhadas.

    Porque pode faltar espaço, mas também pode faltar um lugar fácil de usar. São problemas diferentes. Uma caixa resolve o primeiro.
    Para o segundo, ela pode virar mais uma etapa.

    Imagina uma mochila largada na cadeira todos os dias. Você compra uma caixa bonita e coloca no alto do armário. Agora guardar a mochila
    exige abrir o armário, alcançar a caixa e tirar a tampa. A cadeira continua ali, pronta para receber tudo em um segundo.

    Nessa situação, a questão não é ter onde esconder a mochila. É tornar o lugar certo tão prático quanto a cadeira. Talvez um gancho perto
    da entrada funcione melhor, mesmo ocupando mais espaço à vista.

    Isso não torna as caixas inúteis. Para coisas usadas poucas vezes, elas podem separar e proteger. Só que eu escolheria o recipiente
    depois de decidir como aquele objeto entra na rotina.

    Antes de perguntar o que comprar, eu perguntaria qual movimento precisa ficar mais fácil. Às vezes, organizar é diminuir o esforço
    de guardar, não aumentar a quantidade de lugares disponíveis.
    """

    static var auditText: String { "SYNTHETIC USER:\n" + request + "\nSYNTHETIC ASSISTANT:\n" + response }

    static func transcript(instructions: String) -> Transcript {
        Transcript(entries: [
            .instructions(.init(segments: [.text(.init(content: instructions))], toolDefinitions: [])),
            .prompt(.init(segments: [.text(.init(content: request))])),
            .response(.init(segments: [.text(.init(content: response))])),
        ])
    }
}
