//
//  LanguageSweepCases.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// One case for each of the 20 languages Cue writes in, in `CueLanguage`'s order; none is missing (`LanguageSweepCasesTests` checks it). The
/// topics change from one language to the next (food, fitness, money, study, travel, beauty, productivity, parenting, tech…) and so do the
/// angles, so a language is never judged on one subject alone. Every brief fits the composer whole, whatever the interface's labels
/// (`IdeaPromptDraft.maxCharacters`), so the model gets all of it.
nonisolated enum LanguageSweepCases {
    static let all: [LanguageSweepCase] = [
        LanguageSweepCase(
            language: .english, idea: "5 habits that quietly waste your mornings",
            subject: "The two-minute desk reset", angle: "Show how to clear your desk in two minutes at the end of the day.",
            openingLine: "A messy desk steals more focus than you think.", angleKind: .tutorial, topic: .productivity
        ),
        LanguageSweepCase(
            language: .spanish, idea: "4 errores que arruinan tu tortilla de patatas",
            subject: "Cómo gastar menos en el súper", angle: "Da tres trucos sencillos para ahorrar en la compra de cada semana.",
            openingLine: "La lista de la compra te puede ahorrar más de lo que crees.", angleKind: .list, topic: .finance
        ),
        LanguageSweepCase(
            language: .portugueseBrazil, idea: "3 gastos pequenos que estão detonando seu salário",
            subject: "Reserva de emergência ganhando pouco", angle: "Desminta a ideia de que só quem ganha bem consegue guardar dinheiro.",
            openingLine: "Reserva de emergência não é coisa de quem ganha muito.", angleKind: .myth, topic: .finance
        ),
        LanguageSweepCase(
            language: .french, idea: "3 erreurs qui font que tu oublies tout ce que tu révises",
            subject: "La méthode Pomodoro, ça marche vraiment ?", angle: "Compare des révisions par blocs de 25 minutes et d'une traite.",
            openingLine: "Réviser quatre heures d'affilée, c'est souvent du temps perdu.", angleKind: .comparison, topic: .education
        ),
        LanguageSweepCase(
            language: .german, idea: "5 Fehler, die deinen Muskelaufbau ausbremsen",
            subject: "Muskelkater: weitertrainieren oder Pause?", angle: "Räum mit dem Mythos auf, dass Muskelkater ein gutes Zeichen ist.",
            openingLine: "Muskelkater heißt nicht, dass dein Training gut war.", angleKind: .myth, topic: .fitness
        ),
        LanguageSweepCase(
            language: .italian, idea: "3 errori che rovinano la tua carbonara",
            subject: "Il caffè con la moka fatto bene", angle: "Spiega passo per passo come preparare la moka senza bruciare il caffè.",
            openingLine: "Se il tuo caffè sa di bruciato, il problema è la fiamma.", angleKind: .tutorial, topic: .food
        ),
        LanguageSweepCase(
            language: .japanese, idea: "朝のスキンケアでやりがちな3つの間違い",
            subject: "日焼け止めの正しい塗り直し方", angle: "メイクの上からでもできる塗り直しのコツを紹介する。",
            openingLine: "日焼け止め、朝に塗っただけで安心していませんか？", angleKind: .tutorial, topic: .beauty
        ),
        LanguageSweepCase(
            language: .korean, idea: "공부 집중력을 망치는 습관 3가지",
            subject: "폰 없이 공부하는 법", angle: "공부할 때 휴대폰을 멀리 두는 간단한 방법을 알려 주세요.",
            openingLine: "공부가 안 되는 건 의지가 약해서가 아닐 수도 있어요.", angleKind: .tutorial, topic: .education
        ),
        LanguageSweepCase(
            language: .chineseSimplified, idea: "月光族一定要改掉的3个花钱习惯",
            subject: "记账总是坚持不下去怎么办", angle: "教大家一个每天只花一分钟的记账方法。",
            openingLine: "记账坚持不下去，不是因为你懒。", angleKind: .tutorial, topic: .finance
        ),
        LanguageSweepCase(
            language: .hindi, idea: "वज़न कम करते समय की जाने वाली 3 सबसे बड़ी गलतियाँ",
            subject: "पाँच मिनट में हेल्दी नाश्ता", angle: "पाँच मिनट में बनने वाला एक आसान और पौष्टिक नाश्ता बनाकर दिखाइए।",
            openingLine: "सुबह जल्दी हो, तब भी नाश्ता छोड़ने की ज़रूरत नहीं है।", angleKind: .tutorial, topic: .food
        ),
        LanguageSweepCase(
            language: .indonesian, idea: "5 kesalahan waktu liburan ke Bali yang bikin dompet jebol",
            subject: "Packing satu ransel untuk seminggu", angle: "Tunjukkan cara mengemas barang untuk seminggu cukup dalam satu ransel.",
            openingLine: "Liburan seminggu cukup bawa satu ransel, serius.", angleKind: .tutorial, topic: .travel
        ),
        LanguageSweepCase(
            language: .arabic, idea: "3 عادات تسرق وقتك كل يوم دون أن تشعر",
            subject: "قهوة الصباح: قبل الفطور أم بعده؟", angle: "قارن بين شرب القهوة قبل الفطور وبعده.",
            openingLine: "توقيت قهوتك الصباحية أهم مما تظن.", angleKind: .comparison, topic: .food
        ),
        LanguageSweepCase(
            language: .turkish, idea: "Kombinlerini ucuz gösteren 3 hata",
            subject: "Kapsül gardırop nasıl kurulur?", angle: "Az parçayla çok kombin yapmanın yolunu adım adım anlat.",
            openingLine: "Dolabın dolu ama giyecek bir şeyin yok mu?", angleKind: .tutorial, topic: .fashion
        ),
        LanguageSweepCase(
            language: .thai, idea: "3 ข้อผิดพลาดที่ทำให้ไปเที่ยวญี่ปุ่นแล้วงบบานปลาย",
            subject: "เที่ยวเชียงใหม่ 3 วันแบบประหยัด", angle: "แนะนำวิธีวางแผนทริปสามวันให้คุ้มโดยไม่ต้องรีบ",
            openingLine: "เที่ยวเชียงใหม่ให้สนุกไม่จำเป็นต้องใช้เงินเยอะ", angleKind: .tutorial, topic: .travel
        ),
        LanguageSweepCase(
            language: .vietnamese, idea: "3 sai lầm khiến bạn học tiếng Anh mãi không giỏi",
            subject: "Vì sao học từ vựng mãi không nhớ", angle: "Chỉ ra lỗi phổ biến nhất khi học từ vựng và cách sửa.",
            openingLine: "Học từ mới hôm nay, mai đã quên sạch?", angleKind: .mistake, topic: .education
        ),
        LanguageSweepCase(
            language: .chineseTraditional, idea: "3個讓你越睡越累的壞習慣",
            subject: "睡前滑手機真的那麼糟嗎？", angle: "用簡單的方式解釋睡前看手機對睡眠的影響。",
            openingLine: "睡前滑手機，可能是你早上爬不起來的原因。", angleKind: .fact, topic: .wellness
        ),
        LanguageSweepCase(
            language: .dutch, idea: "3 fouten waardoor bedtijd elke avond een strijd wordt",
            subject: "Een vast avondritueel voor kleine kinderen", angle: "Laat zien hoe je in vier stappen een rustig avondritueel opbouwt.",
            openingLine: "Bedtijd hoeft niet elke avond een gevecht te zijn.", angleKind: .tutorial, topic: .parenting
        ),
        LanguageSweepCase(
            language: .swedish, idea: "3 inställningar i mobilen som tömmer batteriet i onödan",
            subject: "Så rensar du mobilen på fem minuter", angle: "Visa hur man frigör lagringsutrymme utan att radera bilder.",
            openingLine: "Fullt lagringsutrymme igen? Det går att fixa på fem minuter.", angleKind: .tutorial, topic: .tech
        ),
        LanguageSweepCase(
            language: .danish, idea: "3 fejl, der giver ondt i knæene, når du løber",
            subject: "Kom i gang med at løbe", angle: "Forklar, hvordan man kommer i gang med at løbe uden at blive skadet.",
            openingLine: "Du behøver ikke løbe hurtigt for at være en løber.", angleKind: .beginner, topic: .fitness
        ),
        LanguageSweepCase(
            language: .norwegian, idea: "5 ting du må ha med på din første fjelltur",
            subject: "Hytteturen som ikke koster skjorta", angle: "Gi tre konkrete tips til en billig hyttetur med venner.",
            openingLine: "En hyttetur trenger ikke å koste mye.", angleKind: .list, topic: .travel
        ),
    ]
}
