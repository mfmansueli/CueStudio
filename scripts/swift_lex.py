"""Blanks out the comments of Swift source, keeping strings, interpolations and line numbers intact.

Used by strings.py: a key that only a `///` comment mentions is not used by the app.
"""


def blank(text):
    """`text` with every character but the line breaks replaced by a space."""
    return "".join(character if character == "\n" else " " for character in text)


def strip_comments(source, blank_strings=False):
    """`source` with `//` and (nested) `/* */` comments blanked out, and with `blank_strings` the text of string
    literals too (their quotes and the code of their interpolations stay).

    Knows enough Swift to leave comment markers inside strings alone: single-line, multi-line and raw (`#"…"#`)
    literals, and the code inside a string's `\\(…)` interpolation, which can hold strings of its own.
    """
    out = []
    # What the scanner is inside, innermost last: ("code", open parentheses) or ("string", is multi-line, raw hashes).
    stack = [["code", 0]]
    i = 0
    while i < len(source):
        context = stack[-1]
        if context[0] == "code":
            i = scan_code(source, i, stack, out)
        else:
            i = scan_string(source, i, stack, out, multiline=context[1], hashes=context[2], blank_strings=blank_strings)
    return "".join(out)


def scan_code(source, i, stack, out):
    """Handles the code at `source[i]`, appends it to `out` and returns where to go on."""
    code = stack[-1]
    if source.startswith("//", i):
        end = source.find("\n", i)
        end = len(source) if end == -1 else end
        out.append(" " * (end - i))
        return end
    if source.startswith("/*", i):
        end = end_of_block_comment(source, i)
        out.append(blank(source[i:end]))
        return end
    opening = string_opening(source, i)
    if opening:
        length, multiline, hashes = opening
        stack.append(["string", multiline, hashes])
        out.append(source[i:i + length])
        return i + length
    character = source[i]
    if character == "(":
        code[1] += 1
    elif character == ")":
        if code[1] == 0 and len(stack) > 1:
            stack.pop()  # the end of an interpolation: back inside its string
        else:
            code[1] -= 1
    out.append(character)
    return i + 1


def end_of_block_comment(source, i):
    """Where the `/* */` comment that starts at `source[i]` ends (they nest in Swift)."""
    depth = 1
    j = i + 2
    while j < len(source) and depth:
        if source.startswith("/*", j):
            depth += 1
            j += 2
        elif source.startswith("*/", j):
            depth -= 1
            j += 2
        else:
            j += 1
    return j


def string_opening(source, i):
    """(length of the opening, multi-line?, number of `#`) when a string literal starts at `source[i]`."""
    hashes = 0
    while source.startswith("#", i + hashes):
        hashes += 1
    quote = i + hashes
    if source.startswith('"""', quote):
        return hashes + 3, True, hashes
    if source.startswith('"', quote):
        return hashes + 1, False, hashes
    return None


def scan_string(source, i, stack, out, multiline, hashes, blank_strings):
    """Handles the text at `source[i]`, inside a string literal, and returns where to go on."""
    marks = "#" * hashes
    if source.startswith("\\" + marks + "(", i):
        stack.append(["code", 0])
        out.append(source[i:i + 2 + hashes])
        return i + 2 + hashes
    if source[i] == "\\" and hashes == 0:
        out.append(blank(source[i:i + 2]) if blank_strings else source[i:i + 2])
        return i + 2
    closing = ('"""' if multiline else '"') + marks
    if source.startswith(closing, i):
        stack.pop()
        out.append(closing)
        return i + len(closing)
    out.append(blank(source[i]) if blank_strings else source[i])
    return i + 1
