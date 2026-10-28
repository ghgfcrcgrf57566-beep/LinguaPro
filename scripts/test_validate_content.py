import json
import tempfile
import unittest
from pathlib import Path

from validate_content import ContentValidationError, validate_file


VALID_DOCUMENT = {
    "schema_version": 1,
    "content_version": "test-1",
    "lessons": [{
        "id": "a1-test",
        "title": "Test lesson",
        "level": "A1",
        "language": "en",
        "track": "general-english",
        "description": "A test lesson.",
        "objectives": ["Learn one phrase."],
        "vocabulary": [{"term": "hello", "meaning": "مرحبًا", "example": "Hello, Ali."}],
        "sections": [{"heading": "Example", "body": "Hello, my name is Ali."}],
        "quiz": [{
            "question": "Choose the greeting.",
            "options": ["Hello", "Table"],
            "answer_index": 0,
            "explanation": "Hello is a greeting."
        }]
    }]
}


class ContentValidationTests(unittest.TestCase):
    def write_document(self, directory: str, document: dict) -> Path:
        path = Path(directory) / "lessons.json"
        path.write_text(json.dumps(document, ensure_ascii=False), encoding="utf-8")
        return path

    def test_accepts_valid_lesson_file(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(validate_file(self.write_document(directory, VALID_DOCUMENT)), 1)

    def test_accepts_optional_pronunciation_hint(self) -> None:
        document = json.loads(json.dumps(VALID_DOCUMENT))
        document["lessons"][0]["vocabulary"][0]["pronunciation"] = "heh-LOH"
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(validate_file(self.write_document(directory, document)), 1)

    def test_rejects_empty_pronunciation_hint(self) -> None:
        document = json.loads(json.dumps(VALID_DOCUMENT))
        document["lessons"][0]["vocabulary"][0]["pronunciation"] = "  "
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ContentValidationError):
                validate_file(self.write_document(directory, document))

    def test_rejects_out_of_range_answer_index(self) -> None:
        document = json.loads(json.dumps(VALID_DOCUMENT))
        document["lessons"][0]["quiz"][0]["answer_index"] = 7
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ContentValidationError):
                validate_file(self.write_document(directory, document))

    def test_rejects_duplicate_ids(self) -> None:
        document = json.loads(json.dumps(VALID_DOCUMENT))
        document["lessons"].append(json.loads(json.dumps(document["lessons"][0])))
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ContentValidationError):
                validate_file(self.write_document(directory, document))

    def test_accepts_cefr_level_in_legal_english_track(self) -> None:
        document = json.loads(json.dumps(VALID_DOCUMENT))
        lesson = document["lessons"][0]
        lesson["level"] = "B2"
        lesson["track"] = "legal-english"
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(validate_file(self.write_document(directory, document)), 1)

    def test_rejects_legal_level_in_general_track(self) -> None:
        document = json.loads(json.dumps(VALID_DOCUMENT))
        document["lessons"][0]["level"] = "LEGAL"
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ContentValidationError):
                validate_file(self.write_document(directory, document))


if __name__ == "__main__":
    unittest.main()
