//
//  WritingSamples.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// What creators coming from other apps would bring to "Import my writing": each set is one voice, written the way that person writes, so a test can
/// say what Cue should find in it. Invented, short, and not any real creator's.
enum WritingSamples {
    /// An energetic fitness coach: short sentences, exclamations, a catchphrase, questions and numbers to open, "save this" and "try it" to close.
    static let maya: [String] = [
        "Okay, real talk. Do you really need a gym membership? I don't think so! Last month I trained at home for 20 minutes a day. "
            + "Just a mat and two dumbbells. My squat went up and my back pain went down. That's it! Try it for a week and tell me how it feels.",
        "Is your protein actually enough? Okay, real talk. Most people guess! I weighed my food for one week and I was shocked. "
            + "I was eating half of what I needed. Now I track it with one simple app. Easy! Save this and send it to a friend.",
        "3 mistakes ruining your push-ups! Okay, real talk. Number one: your hips sag. Number two: your elbows flare out. "
            + "Number three: you rush every rep. Slow down and squeeze your chest. You'll feel it right away! Try it today and tell me what happens.",
        "Why are your shoulders always sore? Okay, real talk. You skip the warm up! Five minutes. That's all it takes. "
            + "Roll your arms, open your chest, breathe. Do it before every workout and watch the pain fade. Save this for your next session!",
        "7 days. 7 minutes. Okay, real talk. That's all I ask you to do! Wake up, stretch, drink water, move. "
            + "I did this for a month and my energy changed. Don't overthink it! Save this for tomorrow morning.",
        "Can you really build legs at home? Okay, real talk. Yes! Start with squats, then lunges, then a calf raise. "
            + "Train them twice a week and keep it simple. My legs have never felt stronger! Try it this week and tell me how it goes.",
    ]

    /// A calm finance explainer: long sentences, no exclamation marks, one phrase to start with and one to end with.
    static let daniel: [String] = [
        "Most people think investing is complicated, but the core idea is surprisingly simple. Here's the thing: you are buying small pieces of "
            + "companies and holding them while they grow over many years. I started with a single index fund and a monthly transfer that I never "
            + "touched. Over time, the habit mattered more than the amount. If this was useful, follow for part two.",
        "When I look back at my first budget, the biggest mistake was trying to track every single coffee. Here's the thing: a budget only works "
            + "when you can keep it going for a long time. So I moved to three simple categories and checked them once a week. The result was less "
            + "stress and more savings. Follow for part two.",
        "An emergency fund is not an investment, and that is exactly why it works so well. Here's the thing: its only job is to keep you from "
            + "selling anything in a bad month. I keep mine in a boring savings account and I try not to think about it. Follow for part two on how "
            + "much to keep.",
        "Credit scores feel mysterious, yet most of the score comes from two habits that you can control. Here's the thing: paying on time and "
            + "keeping your balances low will carry you most of the way. I check mine once a quarter, not every day. Follow for part two.",
        "Many people ask me whether they should pay off debt or invest first, and the honest answer depends on the interest rate. Here's the "
            + "thing: if the debt costs more than you could reasonably earn, the debt comes first. I have done both, and the order mattered less than "
            + "staying consistent. Follow for part two.",
        "Inflation quietly reduces what your savings can buy, even when the number in your account looks the same. Here's the thing: cash is "
            + "useful for short goals, but long goals need something that can grow. I explain the difference with a simple example. Follow for part two.",
    ]

    /// A beauty creator who writes in Brazilian Portuguese, with slang, a greeting and "salva" and "segue" to close.
    static let rafa: [String] = [
        "Fala, galera! Tipo, você sabe por que seu cabelo quebra? Eu descobri isso semana passada! É o calor da chapinha. "
            + "Bora trocar por um protetor e ver a diferença? Me conta nos comentários se funcionou!",
        "Fala, galera! Hoje eu vou mostrar três truques de maquiagem que mudaram a minha vida. Tipo, sério mesmo! "
            + "O primeiro é usar o corretivo só no cantinho dos olhos. Bora testar? Salva esse vídeo!",
        "Fala, galera! Você erra isso toda manhã e nem percebe. Pare de passar o protetor solar só no rosto! O pescoço também precisa. "
            + "Tipo, é a primeira parte que envelhece. Bora cuidar? Segue pra mais dicas!",
        "Fala, galera! 5 produtos baratos que eu uso todo dia. Tipo, nenhum passa de vinte reais! O meu favorito é o hidratante de farmácia. "
            + "Me conta qual você já usa! Salva pra não esquecer.",
        "Fala, galera! Ontem eu testei aquele batom que todo mundo ama. Tipo, nem é tudo isso! Mas a cor é linda, bora combinar com um blush rosado? "
            + "Comenta aqui o que você achou!",
        "Fala, galera! Minha rotina de noite é simples, tipo, só quatro passos. Limpar, tonificar, hidratar e dormir. "
            + "Bora criar o hábito? Segue pra mais dicas e salva esse vídeo!",
    ]

    /// A small shop that speaks as a team, in Spanish.
    static let lucia: [String] = [
        "Hola, familia. Hoy nosotros vamos a mostrar cómo organizamos nuestra tienda en tres pasos. Primero, nuestro inventario. "
            + "Después, nuestras ofertas. Nosotros creemos que lo simple funciona mejor. Si te sirvió, sígueme para más ideas.",
        "Hola, familia. En nuestro taller nosotros preparamos cada pedido a mano. Nuestro equipo empieza a las siete de la mañana. "
            + "Nosotros cuidamos cada detalle porque nuestros clientes lo notan. Cuéntame abajo qué producto quieres ver.",
        "Hola, familia. Nuestro secreto es que nosotros probamos todo antes de venderlo. Nuestra regla es simple: si no nos gusta, no sale a la tienda. "
            + "Nosotros ya descartamos veinte muestras este mes. Guarda este vídeo para tu próxima compra.",
        "Hola, familia. Nosotros abrimos nuestra tienda hace tres años con una sola mesa. Nuestro primer cliente fue una vecina. "
            + "Nosotros todavía recordamos ese día. Sígueme para ver nuestra historia completa.",
    ]

    /// A paste as it comes out of a notes app: separators, bullets, a title, links, hashtags, a phone number, time stamps and stage cues.
    static let messyPaste = """
    # Script 1 — Morning routine
    00:05 [pause] Okay, real talk. Mornings are hard for me.
    - I drink water first
    - I stretch for five minutes
    - I write one priority on a sticky note
    That is all I do, and it works for me every single day. Follow me @mayafit and see https://example.com/my-routine for the full plan! #morning #routine
    Call me at +1 (555) 123-4567 or write to maya@example.com.

    ---

    Hook: Stop scrolling for ten seconds.
    Body: Most people scroll before they even stand up. I put my phone in the kitchen at night and I wake up calmer. [smile]
    CTA: Save this for tomorrow morning and tell me how it felt.

    ***

    short note about groceries
    """
}
