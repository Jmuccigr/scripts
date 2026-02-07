#!/usr/bin/env -S PYENV_VERSION=venv python3
import sys
import re
import os
import argparse

ETRLETTERS = ["th", "ph", "ch"]  # Letter combos to replace
GKLETTERS = ["θ", "φ", "χ", "k", "([^ae])u"]  # Substitutes to use
GKFINAL = ["th", "ph", "ch", "ei", "\\1y"]  # Substitutes to use
FILEPATH = re.sub("(Documents/).*", "\\1", os.path.dirname(__file__))
MYTHLISTFILE = FILEPATH + "Academic/Greek_mythological_figures.txt"


# Remove 2-letter Roman combos for single Etruscan letters
def clean_word(word: str) -> str:
    for i in range(len(ETRLETTERS)):
        word = re.sub(ETRLETTERS[i], GKLETTERS[i], word)
    word = re.sub("v", "", word)
    return word


# Restore the 2-letter Roman combos
def restore_word(word: str) -> str:
    for i in range(len(GKFINAL)):
        word = re.sub(GKLETTERS[i], GKFINAL[i], word)
    word = re.sub("cs", "x", word)
    return word


def transliterate(word: str, position: int) -> list:
    letter = word[position]
    match letter:
        case "p" | "φ":
            return ["p", "b", "φ"]
        case "c" | "χ":
            return ["c", "g", "χ"]
        case "t" | "θ":
            return ["t", "d", "θ"]
        case "u":
            return ["o", "u"]
        # Have to use a single-letter code for the algo which steps through by letter
        # The k will be replaced by 'ei'
        case "i" if (position != (len(word) - 1)) or (word[-2] != "a"):
            return ["i", "k"]
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
            print(position, "not processing", word)
            newwords.append(word)
    return newwords


def check_endings(wordlist: list) -> list:
    for i in range(len(wordlist)):
        newword = re.sub("s$", "sa", wordlist[i])
        if newword != wordlist[i]:
            wordlist.append(newword)
        newword = re.sub("e$", "eus", wordlist[i])
        if newword != wordlist[i]:
            wordlist.append(newword)
        newword = re.sub("e$", "es", wordlist[i])
        if newword != wordlist[i]:
            wordlist.append(newword)
        newword = re.sub("e$", "os", wordlist[i])
        if newword != wordlist[i]:
            wordlist.append(newword)
        newword = re.sub("e$", "aus", wordlist[i])
        if newword != wordlist[i]:
            wordlist.append(newword)
        newword = re.sub("ai$", "e", wordlist[i])
        wordlist[i] = newword
    return wordlist


def check_beginnings(wordlist: list) -> list:
    for i in range(len(wordlist)):
        newword = re.sub("^zi", "Dio", wordlist[i])
        if newword != wordlist[i]:
            wordlist.append(newword)
        newword = re.sub("^([aeiouk])", "H\\1", wordlist[i])
        if newword != wordlist[i]:
            wordlist.append(newword)
    return wordlist


def double_l(wordlist: list) -> list:
    for i in range(len(wordlist)):
        newword = re.sub("([aeioukə])(l)([aeioukə])", "\\1\\2\\2\\3", wordlist[i])
        if newword != wordlist[i]:
            wordlist.append(newword)
    return wordlist


def double_s(wordlist: list) -> list:
    for i in range(len(wordlist)):
        newword = re.sub("([aeioukə])(s)([aeioukə])", "\\1\\2\\2\\3", wordlist[i])
        if newword != wordlist[i]:
            wordlist.append(newword)
    return wordlist


def convert_cs(wordlist: list) -> list:
    for i in range(len(wordlist)):
        newword = re.sub("cs", "x", wordlist[i])
        if newword != wordlist[i]:
            wordlist.append(newword)
    return wordlist


def check_middles(wordlist: list) -> list:
    newlist = double_l(wordlist)
    newlist = double_s(newlist)
    newlist = convert_cs(newlist)
    return newlist


def insert_epenthetic(wordlist: list) -> list:
    # Inserts epenthetic vowels for 1st 3 occurrences, then all of two consonants
    for i in range(len(wordlist)):
        # 1st occurrence
        newword = re.sub("(.[^aeiouyk])([^aeiouyk])", "\\1ə\\2", wordlist[i], count=1)
        if newword != wordlist[i]:
            wordlist.append(newword)
        # Check for 2nd occurrence in the original word
        newword = re.sub("(.[^aeiouykə])([^aeiouykə])", "\\1ə\\2", newword, count=1)
        w = re.sub("ə", "", newword, count=1)
        if w != wordlist[i]:
            wordlist.append(w)
        # Check for 3rd occurrence in the original word
        newword = re.sub("(.[^aeiouykə])([^aeiouykə])", "\\1ə\\2", newword, count=1)
        w = re.sub("ə", "", newword, count=2)
        if w != wordlist[i]:
            wordlist.append(w)
        # Change all occurrences in the original word
        # Do this twice to catch runs of multiple consonants
        newword = re.sub("([^aeiouykə])([^aeiouykə])", "\\1ə\\2", wordlist[i])
        newword = re.sub("([^aeiouykə])([^aeiouykə])", "\\1ə\\2", newword)
        if newword != wordlist[i]:
            wordlist.append(newword)
    return wordlist


def process_word(wordlist: list) -> list:
    # Get max word length
    l = len(max(wordlist, key=len))

    for position in range(l):
        wordlist = get_new_wordlist(wordlist, position)
    wordlist = check_endings(wordlist)
    wordlist = insert_epenthetic(wordlist)
    wordlist = check_middles(wordlist)
    wordlist = check_beginnings(wordlist)
    finalwords = []
    for word in wordlist:
        finalwords.append(restore_word(word))
    return finalwords


def checklist(wordlist: list) -> list:
    # Checks wordlist against known names
    newlist: list = []
    with open(MYTHLISTFILE, "r") as f:
        namelist = f.read().splitlines()
    for word in wordlist:
        word = word.title()
        words: list = [word]
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
        description='A script to translate Etruscan names to Greek. It accepts names in the Roman alphabet with chi (χ), theta (θ), and phi (φ). The letters "u" and "y" are treated the same when not preceded by "a" or "e".'
    )
    parser.add_argument("Etruscan_name", help="Etruscan name to translate")
    args = parser.parse_args()
    clean_start_word: str = clean_word(args.Etruscan_name.lower())
    result: list = process_word([clean_start_word])
    finallist: list = sorted(checklist(list(set(result))))
    count = len(finallist)
    print(
        f'\nHere is the list of {count} possible Greek names from Etruscan "{args.Etruscan_name}":\n'
    )
    col_print(finallist)
    if "*" in finallist[0]:
        print(f"\nThe asterisked results are known names from Greek mythology.")
    print("")


if __name__ == "__main__":
    main()
