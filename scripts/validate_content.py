#!/usr/bin/env python3
"""Validate LinguaPro lesson JSON with the Python standard library only."""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

LEVELS = {"A1", "A2", "B1", "B2", "C1", "C2", "LEGAL"}
TRACKS = {"general-english", "legal-english"}
ID_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


class ContentValidationError(ValueError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ContentValidationError(message)


def non_empty_string(value: object, label: str) -> None:
    require(isinstance(value, str) and bool(value.strip()), f"{label} must be a non-empty string")


def validate_lesson(lesson: object, file_label: str) -> str:
    require(isinstance(lesson, dict), f"{file_label}: each lesson must be an object")
    required = {"id", "title", "level", "language", "track", "description",
                "objectives", "vocabulary", "sections", "quiz"}
    require(set(lesson) == required,
            f"{file_label}: lesson fields must be exactly {sorted(required)}")
    lesson_id = lesson["id"]
    non_empty_string(lesson_id, f"{file_label}: id")
    require(ID_PATTERN.fullmatch(lesson_id) is not None,
            f"{file_label}: id must use lowercase letters, digits and hyphens")
    for field in ("title", "description"):
        non_empty_string(lesson[field], f"{file_label}: {field}")
    require(lesson["level"] in LEVELS, f"{file_label}: unsupported level {lesson['level']!r}")
    require(lesson["language"] == "en", f"{file_label}: language must be 'en'")
    require(lesson["track"] in TRACKS, f"{file_label}: unsupported track {lesson['track']!r}")
    require(lesson["level"] != "LEGAL" or lesson["track"] == "legal-english",
            f"{file_label}: LEGAL-level lessons must use the legal-english track")

    require(isinstance(lesson["objectives"], list) and lesson["objectives"],
            f"{file_label}: objectives must be a non-empty array")
    for i, objective in enumerate(lesson["objectives"]):
        non_empty_string(objective, f"{file_label}: objectives[{i}]")

    require(isinstance(lesson["vocabulary"], list), f"{file_label}: vocabulary must be an array")
    for i, item in enumerate(lesson["vocabulary"]):
        label = f"{file_label}: vocabulary[{i}]"
        require(isinstance(item, dict) and
                set(item) in ({"term", "meaning", "example"},
                              {"term", "meaning", "example", "pronunciation"}),
                f"{label} must contain term, meaning, example, and optional pronunciation")
        for field in ("term", "meaning", "example"):
            non_empty_string(item[field], f"{label}.{field}")
        if "pronunciation" in item:
            non_empty_string(item["pronunciation"], f"{label}.pronunciation")

    require(isinstance(lesson["sections"], list) and lesson["sections"],
            f"{file_label}: sections must be a non-empty array")
    for i, section in enumerate(lesson["sections"]):
        label = f"{file_label}: sections[{i}]"
        require(isinstance(section, dict) and set(section) == {"heading", "body"},
                f"{label} must contain heading and body only")
        non_empty_string(section["heading"], f"{label}.heading")
        non_empty_string(section["body"], f"{label}.body")

    require(isinstance(lesson["quiz"], list) and lesson["quiz"],
            f"{file_label}: quiz must be a non-empty array")
    for i, question in enumerate(lesson["quiz"]):
        label = f"{file_label}: quiz[{i}]"
        expected = {"question", "options", "answer_index", "explanation"}
        require(isinstance(question, dict) and set(question) == expected,
                f"{label} must contain question, options, answer_index, explanation only")
        non_empty_string(question["question"], f"{label}.question")
        non_empty_string(question["explanation"], f"{label}.explanation")
        options = question["options"]
        require(isinstance(options, list) and len(options) >= 2,
                f"{label}.options must contain at least two choices")
        for j, option in enumerate(options):
            non_empty_string(option, f"{label}.options[{j}]")
        answer_index = question["answer_index"]
        require(isinstance(answer_index, int) and not isinstance(answer_index, bool),
                f"{label}.answer_index must be an integer")
        require(0 <= answer_index < len(options),
                f"{label}.answer_index is outside the options array")
    return lesson_id


def validate_file(path: Path) -> int:
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ContentValidationError(f"{path}: cannot read valid UTF-8 JSON: {exc}") from exc
    require(isinstance(document, dict), f"{path}: root must be an object")
    require(set(document) == {"schema_version", "content_version", "lessons"},
            f"{path}: root must contain schema_version, content_version, lessons only")
    require(document["schema_version"] == 1, f"{path}: unsupported schema_version")
    non_empty_string(document["content_version"], f"{path}: content_version")
    lessons = document["lessons"]
    require(isinstance(lessons, list) and lessons, f"{path}: lessons must be a non-empty array")
    ids = set()
    for lesson in lessons:
        lesson_id = validate_lesson(lesson, str(path))
        require(lesson_id not in ids, f"{path}: duplicate lesson id {lesson_id!r}")
        ids.add(lesson_id)
    return len(lessons)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--content-dir", type=Path, default=Path("content"))
    args = parser.parse_args()
    root = args.content_dir
    files = sorted(root.rglob("*.json")) if root.exists() else []
    files = [path for path in files if path.name != "lessons.schema.json"]
    if not files:
        print(f"ERROR: no lesson JSON files found under {root}", file=sys.stderr)
        return 1
    total = 0
    try:
        for path in files:
            count = validate_file(path)
            total += count
            print(f"OK: {path} ({count} lesson(s))")
    except ContentValidationError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    print(f"Validated {len(files)} content file(s), {total} lesson(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
