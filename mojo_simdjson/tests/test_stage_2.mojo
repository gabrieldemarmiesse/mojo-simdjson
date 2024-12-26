from pathlib import Path
from builtin._location import __call_location
from mojo_simdjson.include.generic.dom_parser_implementation import (
    DomParserImplementation,
)
from mojo_simdjson import errors
from os.path import dirname
from testing import assert_equal
from memory import Span
from mojo_simdjson.include.dom.document import DocumentEntryIterator, Document, DocumentEntry


@always_inline
fn get_current_file_path() -> Path:
    return Path(__call_location().file_name)


fn get_jsons_directory() -> Path:
    current_file_path = get_current_file_path()
    return Path(dirname(current_file_path)) / "jsons_for_test"


def check_stage2(json_file: String):
    json_input = (get_jsons_directory() / json_file).read_text()
    print(json_input.replace("\n", "_"))
    parser = DomParserImplementation()
    error_code = parser.stage1(json_input)
    assert_equal(error_code, 0, "unexpected error code for stage 1")
    error_code = parser.stage2()
    assert_equal(error_code, 0, "unexpected error code for stage 2")



def test_simples_json():
    json_file = "simplest.json"
    check_stage2(json_file)


def test_simple_strings():
    json_file = "simple_strings.json"

    check_stage2(json_file)


def test_escaping():
    json_file = "escaping.json"

    check_stage2(json_file)


def test_escaping_very_long():
    json_file = "escaping_very_long.json"

    check_stage2(json_file)
