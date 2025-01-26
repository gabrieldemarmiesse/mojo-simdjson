from pathlib import Path
from builtin._location import __call_location
from mojo_simdjson.include.generic.dom_parser_implementation import (
    DomParserImplementation,
)
from mojo_simdjson import errors
from os.path import dirname
from testing import assert_equal, assert_true
from memory import Span
from mojo_simdjson.include.dom.document import (
    Document,
    DocumentEntry,
)
from python import Python



@always_inline
fn get_current_file_path() -> Path:
    return Path(__call_location().file_name)


fn get_jsons_directory() -> Path:
    current_file_path = get_current_file_path()
    return Path(dirname(current_file_path)) / "jsons_for_test"


def check_stage2(json_file: String):
    json_input = (get_jsons_directory() / "valid" / json_file).read_text()
    json_input = json_input.splitlines()[0]
    print(json_input)
    parser = DomParserImplementation()
    error_code = parser.stage1(json_input)
    assert_equal(error_code, 0, "unexpected error code for stage 1")
    print("stage 1 done")
    error_code = parser.stage2()
    assert_equal(error_code, 0, "unexpected error code for stage 2")
    print("stage 2 done")
    tup = parser.document.dump_raw_tape()
    raw_tape = tup[0]
    assert_true(tup[1], "dump_raw_tape failed")

    python_json_decoded = Python.import_module("json").loads(json_input)

    _ = json_input


def test_simple_json():
    json_file = "simple_json.json"
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
