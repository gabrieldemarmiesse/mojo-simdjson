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


def verify_expected_structural_characters(
    parser: DomParserImplementation, 
    expected_structural_characters: List[String], 
    json_input: String
):
    #assert_equal(parser.n_structural_indexes, len(expected_structural_characters))

    for i in range(len(expected_structural_characters)):
        assert_equal(json_input[int(parser.structural_indexes[i])], expected_structural_characters[i])
    
    # 3 are leftover
    assert_equal(parser.structural_indexes[int(parser.n_structural_indexes)], UInt32(len(json_input)))
    assert_equal(parser.structural_indexes[int(parser.n_structural_indexes) + 1], UInt32(len(json_input)))
    assert_equal(parser.structural_indexes[int(parser.n_structural_indexes) + 2], UInt32(0))

def test_simples_json():
    json_input = (get_jsons_directory()  / "simplest.json").read_text()
    parser = DomParserImplementation()
    error_code = parser.stage1(json_input)
    assert_equal(error_code, 0)

    expected_structural_characters = List[String]("[", "1", "," , "2", "]")
    verify_expected_structural_characters(parser, expected_structural_characters, json_input)