#!/usr/bin/env -S PYENV_VERSION=venv python3
import sys
import re
import os
import argparse

GKLETTERS = ["ch", "ph", "th", "ei"]  # Letter combos to replace
ETRLETTERS = ["χ", "φ", "θ", "i"]  # Substitutes to use
ROMLETTERS = ["ch", "ph", "th"]  # Substitutes to use
FILEPATH = os.path.dirname(__file__)
MYTHLISTFILE = FILEPATH + "/Etruscan_mythological_figures.txt"


# Remove 2-letter Roman combos for single Etruscan letters
def clean_word(word: str) -> str:
    for i in range(len(GKLETTERS)):
        word = re.sub(GKLETTERS[i], ETRLETTERS[i], word)
    return word


def romanize(wordlist: list) -> list:
    romanizedwords: list = []
    for word in wordlist:
        for i in range(len(ETRLETTERS) - 1):
            word = re.sub(ETRLETTERS[i], ROMLETTERS[i], word)
        romanizedwords.append(word)
    return romanizedwords


def transliterate(word: str, position: int) -> list:
    letter = word[position]
    match letter:
        case "b" | "φ" | "p":
            return ["p", "φ"]
        case "d" | "θ" | "t":
            return ["t", "θ"]
        case "g":
            return ["c"]
        case "o" | "y":
            return ["u"]
        case "k":
            return ["c"]
        case "e" if position == (len(word) - 1):
            return ["e", "ai"]
        case _:
            return [letter]


# Go through a list of words and create a new list based on it
# Then send the new list off for processing
def get_new_wordlist(wordlist: list, position: int) -> list:
    newwords: list = []
    for word in wordlist:
        if position < len(word):
            newletters: list = transliterate(word, position)
            for letter in newletters:
                newword = word[0:position] + letter + word[position + 1 :]
                newwords.append(newword)
        else:
            newwords.append(word)
    return newwords


def check_endings(wordlist: list) -> list:
    for i in range(len(wordlist)):
        newword = re.sub("[ae]*us$", "e", wordlist[i])
        newword = re.sub("es$", "e", newword)
        newword = re.sub("er$", "re", newword)
        wordlist[i] = newword
    return wordlist


def check_beginnings(wordlist: list) -> list:
    for i in range(len(wordlist)):
        newword = re.sub("^h", "", wordlist[i])
        # Can reuse here because there is no chance of getting 'hdoi' at the start
        newword = re.sub("^dio", "zi", newword)
        if newword != wordlist[i]:
            wordlist.append(newword)
    return wordlist


def deduple(wordlist: list) -> list:
    newlist: list = []
    for i in range(len(wordlist)):
        newword = re.sub("(.)\\1", "\\1", wordlist[i])
        newlist.append(newword)
    return newlist


def convert_x(wordlist: list) -> list:
    newlist: list = []
    for i in range(len(wordlist)):
        # This will change all -x- in a word, but >1 is rare
        if "x" in wordlist[i]:
            for l in ["cs", "χs"]:
                newword = re.sub("x", l, wordlist[i])
                newlist.append(newword)
        else:
            newlist.append(wordlist[i])
    return newlist


def check_middles(wordlist: list) -> list:
    newlist: list = deduple(wordlist)
    newlist = convert_x(newlist)
    return newlist


def remove_epenthetic(wordlist: list) -> list:
    # Removes epenthetic vowels for 1st 2 occurrences of two consonants
    for i in range(len(wordlist)):
        # 1st occurrence
        newword = re.sub(
            "([aeiou][^aeiou]+)[aeiou]([^aeiou]+[aeiou]+)",
            "\\1\\2",
            wordlist[i],
            count=1,
        )
        if newword != wordlist[i]:
            wordlist.append(newword)
    return wordlist


def process_word(wordlist: list) -> list:
    # Get max word length
    wordlist = check_beginnings(wordlist)
    l = len(max(wordlist, key=len))
    for position in range(l):
        wordlist = get_new_wordlist(wordlist, position)
    wordlist = check_endings(wordlist)
    wordlist = remove_epenthetic(wordlist)
    wordlist = check_middles(wordlist)
    finalwords = []
    #     for word in wordlist:
    #         finalwords.append(restore_word(word))
    return wordlist


def checklist(wordlist: list) -> list:
    newlist: list = []
    with open(MYTHLISTFILE, "r") as f:
        namelist = f.read().splitlines()
    namelist = list(set(namelist + romanize(namelist)))
    for word in wordlist:
        word = word.title()
        words: list = [word]
        #         words.append(word.title())
        if "ə" in word:
            for v in "aeiouy":
                words.append(re.sub("ə", v, word))
        for w in words:
            for name in namelist:
                if w == name:
                    newlist.append("*" + w)
                    break
            else:
                # Just use the schwa version instead of all the vowels
                if len(newlist) == 0 or newlist[-1] != word:
                    newlist.append(word)
    return newlist


def col_print(lines, term_width=80, indent=0, pad=2) -> None:
    n_lines = len(lines)
    if n_lines == 0:
        return
    col_width = max(len(line) for line in lines) + pad
    n_cols = (term_width + pad - indent) // col_width
    n_cols = min(n_lines, max(1, n_cols))
    col_len = (n_lines // n_cols) + (0 if n_lines % n_cols == 0 else 1)
    if (n_cols - 1) * col_len >= n_lines:
        n_cols -= 1
    while n_lines % n_cols != 0:
        lines.append("")
        n_lines = len(lines)
    cols = [lines[i * col_len : i * col_len + col_len] for i in range(n_cols)]
    rows = list(zip(*cols))
    rows_missed = zip(*[col[len(rows) :] for col in cols[:-1]])
    rows.extend(rows_missed)
    for row in rows:
        print(" " * indent + ("").join(line.ljust(col_width) for line in row))


def main():
    parser = argparse.ArgumentParser(
        description="A script to translate Greek names to Etruscan."
    )
    parser.add_argument("Greek_name", help="Greek name to translate")
    parser.add_argument(
        "-r",
        "--romanize",
        action="store_true",
        help="Output only Roman letters (ch, ph, th)",
    )
    args = parser.parse_args()
    clean_start_word: str = clean_word(args.Greek_name.lower())
    result: list = process_word([clean_start_word])
    if args.romanize:
        result = romanize(result)
    finallist: list = sorted(checklist(list(set(result))))
    count = len(finallist)
    print(
        f'\nHere is the list of {count} possible Etruscan names from  Greek "{args.Greek_name}":\n'
    )
    col_print(finallist)
    if "*" in finallist[0]:
        print(f"\nThe asterisked results are known names from Etruscan inscriptions.")
    print("")


if __name__ == "__main__":
    main()
