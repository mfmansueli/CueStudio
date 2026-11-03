//
//  SampleAIDraft.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// A long script as Ultra AI writes one for YouTube (`-uiTestAIDraft`): about 800 words in Portuguese, a few cues, the language left to
/// Auto-detect, the fact check waiting, a draft. What the owner typed into when the words lagged and a script of their own didn't
/// (03/11/2026); `PerformanceDeviceUITests` types into it on a real iPhone. Never shipped.
nonisolated enum SampleAIDraft {
    static let title = "Acordei às 5h por 30 dias: o que ninguém te conta"

    static let script: Script = {
        var script = Script(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!,
            title: title, text: text, platform: .youtube, type: .story,
            createdAt: .now.addingTimeInterval(-60), updatedAt: .now.addingTimeInterval(-60), factCheck: true, isFinished: false
        )
        script.draftedBy = .ultra
        return script
    }()

    static let text = """
    Durante trinta dias seguidos eu acordei às cinco da manhã, e hoje eu vou te contar tudo o que aconteceu, inclusive as partes que \
    ninguém mostra nos vídeos de rotina perfeita. [pause] Se você já tentou acordar mais cedo e desistiu na primeira semana, fica comigo \
    até o final, porque o que mudou para mim não foi o horário. Foi o que eu fiz com ele.

    Antes de começar, um pouco de contexto. Eu trabalho de casa, edito vídeos até tarde e, durante anos, achei que eu simplesmente não era \
    uma pessoa da manhã. Eu dormia depois da meia-noite, acordava cansado e passava a primeira hora do dia rolando o feed no celular. Um dia \
    eu percebi que estava sempre correndo atrás do relógio, e que nunca sobrava tempo para as coisas que eu dizia que eram importantes. \
    Foi aí que eu decidi testar esse desafio de verdade, com regras claras e anotando tudo num caderno. [look at camera]

    As regras eram simples. Primeiro: despertador às cinco, todos os dias, inclusive no fim de semana. Segundo: nada de celular na primeira \
    hora. Terceiro: dormir às nove e meia, no máximo às dez. E quarto: anotar como eu me sentia, de zero a dez, em energia, humor e foco. \
    Parece fácil quando a gente escreve, mas a primeira semana foi, sinceramente, um desastre.

    Nos primeiros quatro dias eu acordei com dor de cabeça e uma vontade enorme de voltar para a cama. Eu tomava café e ficava sentado olhando \
    para a parede, sem saber o que fazer com aquele tempo todo. No quinto dia eu desliguei o despertador e dormi até as oito. Eu me senti um \
    fracasso. [pause] Mas foi justamente nesse dia que eu entendi o primeiro erro: eu tinha mudado a hora de acordar, mas não tinha mudado a \
    hora de dormir. Eu estava dormindo cinco horas por noite e esperando acordar cheio de energia.

    Na segunda semana eu levei a regra do sono a sério. Coloquei um alarme às nove da noite para começar a desligar tudo: tela, luz forte, \
    notificação. Li um livro de papel, tomei um chá e, na maioria das noites, dormi antes das dez. A diferença foi imediata. No décimo dia eu \
    acordei antes do despertador, e esse foi o primeiro momento em que eu pensei: talvez isso funcione.

    Com o sono no lugar, eu precisava resolver o segundo problema: o que fazer com a manhã. Eu montei uma rotina curta, de quarenta minutos. \
    Dez minutos de alongamento, dez minutos escrevendo três coisas que eu queria fazer no dia, e vinte minutos de trabalho focado na tarefa \
    mais difícil, aquela que eu normalmente empurrava para depois. [smile] Só isso. Nada de rotina de duas horas com banho gelado, meditação, \
    diário, leitura e corrida. Quarenta minutos que eu conseguia repetir mesmo num dia ruim.

    A terceira semana foi a melhor. Minha nota de foco, que começou em quatro, chegou a oito. Eu terminei um projeto que estava parado há \
    dois meses e, pela primeira vez em muito tempo, cheguei no fim do dia sem aquela sensação de que tinha corrido o dia inteiro sem sair do \
    lugar. O mais curioso é que eu não estava trabalhando mais horas. Eu só estava começando o dia pelo que importava, antes que o mundo \
    começasse a pedir coisas de mim.

    Mas nem tudo foi perfeito, e eu prometi te contar as partes que ninguém mostra. Acordar às cinco mexeu com a minha vida social. Eu recusei \
    jantares, saí cedo de um aniversário e, num sábado, dormi no sofá às oito e meia da noite. Também teve dia em que eu acordei, fiz a rotina \
    inteira e, mesmo assim, o dia foi improdutivo. O horário não é mágico. Ele só te dá um espaço em silêncio, e o que você faz com esse \
    espaço depende de você.

    Na última semana eu fiz um teste: voltei a acordar às sete, mas mantive a mesma rotina de quarenta minutos e o mesmo horário de dormir \
    proporcional. E sabe o que aconteceu? A maior parte dos benefícios continuou. Foi aí que eu entendi a lição principal desse desafio. \
    O segredo não era acordar às cinco. Era dormir o suficiente, proteger a primeira hora do dia do celular e fazer a coisa mais importante \
    antes de qualquer outra.

    Então, se você quer testar isso, o meu conselho é: não comece pelo despertador. Comece pela hora de dormir. Escolha uma rotina curta, que \
    você consiga repetir até num dia péssimo, e anote como você se sente durante pelo menos duas semanas, porque a primeira sempre engana. \
    [look at camera] E me conta aqui nos comentários: qual é o horário em que você acorda hoje, e o que você faria com uma hora a mais só \
    para você? Se esse vídeo te ajudou, se inscreve no canal, porque no próximo eu vou mostrar o caderno inteiro com as notas de cada dia.
    """
}
#endif
