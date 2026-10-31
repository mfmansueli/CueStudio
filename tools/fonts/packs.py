"""The script libraries (FontPacks.json): free families from github.com/google/fonts, pinned to one commit.

Each family: its directory in the repository, the script it is chosen for, its character (the class of Latin face it
stands in for: TypeCharacter in the app) and the files the app may download, each with its weight (static cuts) or none
(a variable file, whose weight axis the app reads). Only the cuts the editor's weights need are listed (Regular 400 to
Black 900), so a creator downloads one file per weight they use.

    tools/fonts/make_manifest.py  downloads every file once, checks it, and writes the manifest with SHA-256 and size.
"""

COMMIT = "6c1dbe27dcf7d817d4b62cec033ba77fa8e2a5ec"

# (directory, script, character, [(file, weight or None)])
FAMILIES = [
    # Japanese
    ("zenkakugothicnew", "japanese", "sans", [("ZenKakuGothicNew-Regular.ttf", 400), ("ZenKakuGothicNew-Medium.ttf", 500),
                                               ("ZenKakuGothicNew-Bold.ttf", 700), ("ZenKakuGothicNew-Black.ttf", 900)]),
    ("mplusrounded1c", "japanese", "rounded", [("MPLUSRounded1c-Regular.ttf", 400), ("MPLUSRounded1c-Medium.ttf", 500),
                                              ("MPLUSRounded1c-Bold.ttf", 700), ("MPLUSRounded1c-ExtraBold.ttf", 800),
                                              ("MPLUSRounded1c-Black.ttf", 900)]),
    ("zenmarugothic", "japanese", "rounded", [("ZenMaruGothic-Regular.ttf", 400), ("ZenMaruGothic-Medium.ttf", 500),
                                             ("ZenMaruGothic-Bold.ttf", 700), ("ZenMaruGothic-Black.ttf", 900)]),
    ("delagothicone", "japanese", "condensed", [("DelaGothicOne-Regular.ttf", 400)]),
    ("reggaeone", "japanese", "comic", [("ReggaeOne-Regular.ttf", 400)]),
    ("mochiypopone", "japanese", "wide", [("MochiyPopOne-Regular.ttf", 400)]),
    ("zenoldmincho", "japanese", "serif", [("ZenOldMincho-Regular.ttf", 400), ("ZenOldMincho-Bold.ttf", 700),
                                          ("ZenOldMincho-Black.ttf", 900)]),
    ("yomogi", "japanese", "handwritten", [("Yomogi-Regular.ttf", 400)]),
    ("hachimarupop", "japanese", "handwritten", [("HachiMaruPop-Regular.ttf", 400)]),
    ("mplus1code", "japanese", "mono", [("MPLUS1Code[wght].ttf", None)]),
    # Chinese, simplified
    ("notosanssc", "chineseSimplified", "sans", [("NotoSansSC[wght].ttf", None)]),
    ("zcoolkuaile", "chineseSimplified", "rounded", [("ZCOOLKuaiLe-Regular.ttf", 400)]),
    ("zcoolqingkehuangyou", "chineseSimplified", "condensed", [("ZCOOLQingKeHuangYou-Regular.ttf", 400)]),
    ("zcoolxiaowei", "chineseSimplified", "serif", [("ZCOOLXiaoWei-Regular.ttf", 400)]),
    ("mashanzheng", "chineseSimplified", "comic", [("MaShanZheng-Regular.ttf", 400)]),
    ("longcang", "chineseSimplified", "handwritten", [("LongCang-Regular.ttf", 400)]),
    ("zhimangxing", "chineseSimplified", "handwritten", [("ZhiMangXing-Regular.ttf", 400)]),
    # Chinese, traditional
    ("notosanstc", "chineseTraditional", "sans", [("NotoSansTC[wght].ttf", None)]),
    ("huninn", "chineseTraditional", "rounded", [("Huninn-Regular.ttf", 400)]),
    ("notoseriftc", "chineseTraditional", "serif", [("NotoSerifTC[wght].ttf", None)]),
    ("lxgwwenkaitc", "chineseTraditional", "handwritten", [("LXGWWenKaiTC-Regular.ttf", 400), ("LXGWWenKaiTC-Bold.ttf", 700)]),
    ("iansui", "chineseTraditional", "comic", [("Iansui-Regular.ttf", 400)]),
    # Korean
    ("blackhansans", "korean", "wide", [("BlackHanSans-Regular.ttf", 400)]),
    ("dohyeon", "korean", "condensed", [("DoHyeon-Regular.ttf", 400)]),
    ("gasoekone", "korean", "condensed", [("GasoekOne-Regular.ttf", 400)]),
    ("jua", "korean", "rounded", [("Jua-Regular.ttf", 400)]),
    ("bagelfatone", "korean", "comic", [("BagelFatOne-Regular.ttf", 400)]),
    ("nanummyeongjo", "korean", "serif", [("NanumMyeongjo-Regular.ttf", 400), ("NanumMyeongjo-Bold.ttf", 700),
                                         ("NanumMyeongjo-ExtraBold.ttf", 800)]),
    ("nanumpenscript", "korean", "handwritten", [("NanumPenScript-Regular.ttf", 400)]),
    ("gaegu", "korean", "handwritten", [("Gaegu-Regular.ttf", 400), ("Gaegu-Bold.ttf", 700)]),
    # Arabic
    ("cairo", "arabic", "sans", [("Cairo[slnt,wght].ttf", None)]),
    ("almarai", "arabic", "sans", [("Almarai-Regular.ttf", 400), ("Almarai-Bold.ttf", 700), ("Almarai-ExtraBold.ttf", 800)]),
    ("reemkufi", "arabic", "geometric", [("ReemKufi[wght].ttf", None)]),
    ("lemonada", "arabic", "rounded", [("Lemonada[wght].ttf", None)]),
    ("changa", "arabic", "condensed", [("Changa[wght].ttf", None)]),
    ("lalezar", "arabic", "wide", [("Lalezar-Regular.ttf", 400)]),
    ("marhey", "arabic", "comic", [("Marhey[wght].ttf", None)]),
    ("amiri", "arabic", "serif", [("Amiri-Regular.ttf", 400), ("Amiri-Bold.ttf", 700)]),
    ("elmessiri", "arabic", "serif", [("ElMessiri[wght].ttf", None)]),
    ("arefruqaa", "arabic", "handwritten", [("ArefRuqaa-Regular.ttf", 400), ("ArefRuqaa-Bold.ttf", 700)]),
    # Devanagari (Poppins, bundled, already draws it: the geometric class)
    ("mukta", "devanagari", "sans", [("Mukta-Regular.ttf", 400), ("Mukta-Medium.ttf", 500), ("Mukta-SemiBold.ttf", 600),
                                    ("Mukta-Bold.ttf", 700), ("Mukta-ExtraBold.ttf", 800)]),
    ("hind", "devanagari", "sans", [("Hind-Regular.ttf", 400), ("Hind-Medium.ttf", 500), ("Hind-SemiBold.ttf", 600),
                                   ("Hind-Bold.ttf", 700)]),
    ("baloo2", "devanagari", "rounded", [("Baloo2[wght].ttf", None)]),
    ("teko", "devanagari", "condensed", [("Teko[wght].ttf", None)]),
    ("khand", "devanagari", "condensed", [("Khand-Regular.ttf", 400), ("Khand-Medium.ttf", 500), ("Khand-SemiBold.ttf", 600),
                                         ("Khand-Bold.ttf", 700)]),
    ("yatraone", "devanagari", "comic", [("YatraOne-Regular.ttf", 400)]),
    ("rozhaone", "devanagari", "serif", [("RozhaOne-Regular.ttf", 400)]),
    ("martel", "devanagari", "serif", [("Martel-Regular.ttf", 400), ("Martel-Bold.ttf", 700), ("Martel-ExtraBold.ttf", 800),
                                      ("Martel-Heavy.ttf", 900)]),
    ("kalam", "devanagari", "handwritten", [("Kalam-Regular.ttf", 400), ("Kalam-Bold.ttf", 700)]),
    # Thai
    ("kanit", "thai", "sans", [("Kanit-Regular.ttf", 400), ("Kanit-Medium.ttf", 500), ("Kanit-SemiBold.ttf", 600),
                              ("Kanit-Bold.ttf", 700), ("Kanit-ExtraBold.ttf", 800), ("Kanit-Black.ttf", 900)]),
    ("prompt", "thai", "geometric", [("Prompt-Regular.ttf", 400), ("Prompt-Medium.ttf", 500), ("Prompt-SemiBold.ttf", 600),
                                    ("Prompt-Bold.ttf", 700), ("Prompt-ExtraBold.ttf", 800), ("Prompt-Black.ttf", 900)]),
    ("mitr", "thai", "rounded", [("Mitr-Regular.ttf", 400), ("Mitr-Medium.ttf", 500), ("Mitr-SemiBold.ttf", 600),
                                ("Mitr-Bold.ttf", 700)]),
    ("mali", "thai", "comic", [("Mali-Regular.ttf", 400), ("Mali-SemiBold.ttf", 600), ("Mali-Bold.ttf", 700)]),
    ("chakrapetch", "thai", "mono", [("ChakraPetch-Regular.ttf", 400), ("ChakraPetch-SemiBold.ttf", 600),
                                     ("ChakraPetch-Bold.ttf", 700)]),
    ("trirong", "thai", "serif", [("Trirong-Regular.ttf", 400), ("Trirong-Bold.ttf", 700), ("Trirong-Black.ttf", 900)]),
    ("itim", "thai", "handwritten", [("Itim-Regular.ttf", 400)]),
    ("sriracha", "thai", "handwritten", [("Sriracha-Regular.ttf", 400)]),
    ("charm", "thai", "handwritten", [("Charm-Regular.ttf", 400), ("Charm-Bold.ttf", 700)]),
]

# The family's name as Google Fonts shows it, where the file's own name differs.
NAMES = {
    "mplusrounded1c": "M PLUS Rounded 1c",
    "zcoolxiaowei": "ZCOOL XiaoWei",
    "nanummyeongjo": "Nanum Myeongjo",
    "nanumpenscript": "Nanum Pen Script",
}
