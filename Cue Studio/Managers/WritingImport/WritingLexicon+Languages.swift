//
//  WritingLexicon+Languages.swift
//  Cue Studio
//

import Foundation

nonisolated extension WritingLexicon {
    static let all: [String: WritingLexicon] = [
        "en": english, "pt": portuguese, "es": spanish, "fr": french, "de": german, "it": italian,
    ]

    private static func words(_ text: String) -> Set<String> {
        Set(text.split(separator: " ").map(String.init))
    }

    static let english = WritingLexicon(
        singular: words("i i'm i’m i've i’ve i'll i’ll i'd i’d my me mine myself"),
        plural: words("we we're we’re we've we’ve we'll we’ll we'd we’d our ours us ourselves"),
        filler: words(
            "the a an and or but to of in on at for with is are was were be it its this that you your i my me we our so if do don't don’t not no yes can "
                + "will just like as by from up out all have has had they them he she what how why when there here then than now about into more very"
        ),
        slang: words("gonna wanna gotta kinda sorta lol omg bro dude nah yeah yep y'all tbh ngl lowkey vibe vibes guys fam chill legit"),
        mildSwearing: words("damn hell crap freaking bloody sucks darn"),
        storyStarts: [
            "i used to", "last week", "last year", "yesterday", "when i ", "one day", "a few years ago", "years ago", "this morning",
            "last night", "the other day", "so i ", "i remember", "i was ",
        ],
        mistakeStarts: ["stop ", "never ", "don't ", "don’t ", "do not ", "the biggest mistake", "mistake", "avoid ", "quit "],
        save: ["save this", "save it", "save for later", "bookmark"],
        follow: ["follow", "subscribe"],
        comment: ["comment", "tell me", "let me know", "drop a", "what do you think", "which one", "in the comments", "below"],
        linkInBio: ["link in bio", "link in my bio", "link below", "check the link", " bio"],
        tryIt: ["try it", "give it a try", "try this", "try one", "try and tell", "try and let me know"],
        numberWords: words("one two three four five six seven eight nine ten"),
        expertWordLength: 5.1, plainWordLength: 4.4
    )

    static let portuguese = WritingLexicon(
        singular: words("eu meu minha meus minhas mim comigo"),
        plural: words("nós nosso nossa nossos nossas conosco"),
        filler: words(
            "o a os as um uma uns umas de do da dos das em no na nos nas por para com sem e ou mas que se é são foi era ser ter tem você vocês seu sua "
                + "eu meu minha não sim já só mais muito isso essa esse este esta aqui ali então como quando porque pra pro né te me nos lhe"
        ),
        slang: words("tipo mano cara né vc vcs pq tb tá galera bora massa mt kkk top brother véi mina"),
        mildSwearing: words("droga caramba poxa puxa porcaria saco inferno"),
        storyStarts: [
            "eu era", "eu costumava", "semana passada", "ano passado", "ontem", "quando eu", "um dia", "há alguns anos", "anos atrás",
            "hoje cedo", "ontem à noite", "lembro", "outro dia", "eu estava",
        ],
        mistakeStarts: ["pare de", "para de", "nunca", "não ", "evite", "o maior erro", "erro", "deixa de"],
        save: ["salve", "salva ", "guarde", "guarda ", "salvar"],
        follow: ["siga", "segue", "se inscreva", "inscreva"],
        comment: ["comente", "comenta", "conta pra mim", "me conta", "me diga", "nos comentários", "embaixo"],
        linkInBio: ["link na bio", "link da bio", "link no perfil", " bio"],
        tryIt: ["teste", "testa ", "experimente", "experimenta", "tente", "tenta "],
        numberWords: words("um dois três quatro cinco seis sete oito nove dez"),
        expertWordLength: 5.6, plainWordLength: 4.8
    )

    static let spanish = WritingLexicon(
        singular: words("yo mi mis mío mía conmigo"),
        plural: words("nosotros nosotras nuestro nuestra nuestros nuestras"),
        filler: words(
            "el la los las un una unos unas de del en y o pero que se es son fue era ser tiene tú usted tu su yo mi no sí ya solo más muy esto eso esta "
                + "este aquí allí entonces como cuando porque pues para por con sin al lo le les me te nos"
        ),
        slang: words("tío tía guay vale bro wey güey chévere chido pa q xq jaja"),
        mildSwearing: words("caray rayos demonios jolín"),
        storyStarts: [
            "yo solía", "la semana pasada", "el año pasado", "ayer", "cuando yo", "un día", "hace unos años", "hace años", "esta mañana",
            "anoche", "el otro día", "recuerdo", "yo estaba",
        ],
        mistakeStarts: ["deja de", "para de", "nunca", "no ", "evita", "el mayor error", "error"],
        save: ["guarda", "guárdalo", "guardalo"],
        follow: ["sígueme", "sigueme", "suscríbete", "síguenos"],
        comment: ["comenta", "cuéntame", "dime", "déjame", "en los comentarios", "abajo"],
        linkInBio: ["enlace en mi bio", "link en mi bio", "link en la bio", "enlace en la bio", " bio"],
        tryIt: ["prueba", "pruébalo", "inténtalo", "intenta"],
        numberWords: words("uno dos tres cuatro cinco seis siete ocho nueve diez"),
        expertWordLength: 5.4, plainWordLength: 4.6
    )

    static let french = WritingLexicon(
        singular: words("je j' mon ma mes moi"),
        plural: words("nous notre nos"),
        filler: words(
            "le la les un une des de du en et ou mais que qui se est sont était être avoir a tu vous ton ta votre je mon ma ne pas oui déjà plus très "
                + "ce cette ces ici alors comme quand parce pour par avec sans au aux il elle on"
        ),
        slang: words("mec ouf carrément grave trop genre bref"),
        mildSwearing: words("zut mince flûte"),
        storyStarts: ["avant, je", "la semaine dernière", "l'année dernière", "hier", "quand j", "un jour", "il y a quelques années", "ce matin", "hier soir"],
        mistakeStarts: ["arrête", "arrêtez", "ne ", "jamais", "évite", "évitez", "la plus grosse erreur", "erreur"],
        save: ["enregistre", "enregistrez", "sauvegarde", "garde cette"],
        follow: ["abonne", "suis-moi", "suivez", "suis "],
        comment: ["commente", "commentez", "dis-moi", "dites-moi", "en commentaire", "ci-dessous"],
        linkInBio: ["lien en bio", "lien dans ma bio", " bio"],
        tryIt: ["essaie", "essayez", "teste", "testez"],
        numberWords: words("un deux trois quatre cinq six sept huit neuf dix"),
        expertWordLength: 5.5, plainWordLength: 4.7
    )

    static let german = WritingLexicon(
        singular: words("ich mein meine meinen meinem meiner mir mich"),
        plural: words("wir unser unsere unseren unserem uns"),
        filler: words(
            "der die das ein eine und oder aber zu von in auf an für mit ist sind war waren sein es du dein ich mein nicht ja schon nur mehr sehr "
                + "dies diese dieser hier dann wie wenn weil den dem des im am"
        ),
        slang: words("krass geil digga alter mega echt halt"),
        mildSwearing: words("mist verdammt"),
        storyStarts: [
            "früher habe ich", "letzte woche", "letztes jahr", "gestern", "als ich", "eines tages", "vor ein paar jahren", "heute morgen",
            "gestern abend",
        ],
        mistakeStarts: ["hör auf", "nie ", "nicht ", "vermeide", "der größte fehler", "fehler"],
        save: ["speicher", "speichere", "abspeichern"],
        follow: ["folge", "abonniere", "folg "],
        comment: ["kommentiere", "schreib mir", "sag mir", "in die kommentare", "unten"],
        linkInBio: ["link in der bio", "link in meiner bio", " bio"],
        tryIt: ["probier", "probiere", "teste", "versuch"],
        numberWords: words("eins zwei drei vier fünf sechs sieben acht neun zehn"),
        expertWordLength: 6.6, plainWordLength: 5.6
    )

    static let italian = WritingLexicon(
        singular: words("io mio mia miei mie me"),
        plural: words("noi nostro nostra nostri nostre"),
        filler: words(
            "il lo la i gli le un una uno di del della dei delle in e o ma che si è sono era essere ha tu voi tuo tua vostro io mio mia non sì già solo più "
                + "molto questo questa qui lì allora come quando perché per con senza al ai"
        ),
        slang: words("raga bro figo boh tipo cioè"),
        mildSwearing: words("accidenti caspita mannaggia"),
        storyStarts: ["io ero", "la settimana scorsa", "l'anno scorso", "ieri", "quando io", "un giorno", "qualche anno fa", "stamattina", "ieri sera"],
        mistakeStarts: ["smetti di", "smettila", "mai ", "non ", "evita", "il più grande errore", "errore"],
        save: ["salva", "salvalo"],
        follow: ["seguimi", "segui", "iscriviti"],
        comment: ["commenta", "scrivimi", "dimmi", "nei commenti", "qui sotto"],
        linkInBio: ["link in bio", "link nella bio", " bio"],
        tryIt: ["prova", "provalo", "testa"],
        numberWords: words("uno due tre quattro cinque sei sette otto nove dieci"),
        expertWordLength: 5.7, plainWordLength: 4.9
    )
}
