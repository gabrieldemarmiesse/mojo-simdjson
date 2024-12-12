from pathlib import Path
from builtin._location import __call_location
from mojo_simdjson.include.generic.dom_parser_implementation import DomParserImplementation
from mojo_simdjson import errors
from os.path import dirname
from testing import assert_equal
from memory import Span

@always_inline
fn get_current_file_path() -> Path:
    return Path(__call_location().file_name)

fn get_jsons_directory() -> Path:
    current_file_path = get_current_file_path()
    return Path(dirname(current_file_path)) / "jsons_for_test"

def test_simples_json():
    json_input = (get_jsons_directory()  / "simplest.json").read_text()
    parser = DomParserImplementation()
    error_code = parser.stage1(Span(json_input._buffer))
    assert_equal(error_code, 0)