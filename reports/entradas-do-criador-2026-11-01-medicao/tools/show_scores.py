import json, sys
r = json.load(open(sys.argv[1]))
for x in r:
    base = "%-17s %-6s %-12s i%d %4dw %5ss" % (x["case"], x["route"], x["model"], x["i"], x["words"], x["s"])
    if "F" in x:
        print(base, "F", x["F"], "M", x["M"], " | ".join(h[0] + ":" + h[1][-50:] for h in x["hits"])[:420])
    else:
        print(base, "cta", x["cta_in_last"], "follow", x["follow_in_last"], "q", x["opens_with_question"], "phrase", x["catchphrase"], "| LAST:", x["last"][:130])
    if x.get("failure"):
        print("   FAIL", x["failure"][:150])
