from pathlib import Path
from builtin._location import __call_location
from mojo_simdjson.include.generic.dom_parser_implementation import (
    DomParserImplementation,
)
from memory import UnsafePointer
from mojo_simdjson import errors
from os.path import dirname
from testing import assert_equal, assert_true, assert_raises
from memory import Span


@always_inline
fn get_current_file_path() -> Path:
    return Path(__call_location().file_name)


fn get_jsons_directory() -> Path:
    current_file_path = get_current_file_path()
    return Path(dirname(current_file_path)) / "jsons_for_test"


def assert_strictly_increasing(array: List[UInt32], length: UInt32):
    print("length", length)
    for i in range(1, length):
        print("test", i)
        assert_true(array[i - 1] < array[i])


def assert_tagging_is_correct(
    json_input: String,
    expected_structural_characters: String,
):
    for i in range(min(len(json_input), len(expected_structural_characters))):
        if expected_structural_characters[i] != "1":
            continue
        if not json_input[i] in '{}[]:,tfn-0123456789"':
            raise Error(
                "Wrong tagging of characters, "
                + json_input[i]
                + " is not a structural character"
            )


def verify_expected_structural_characters(
    parser: DomParserImplementation,
    expected_structural_characters: String,
    json_input: String,
):
    print("n_structural_indexes", parser.n_structural_indexes)
    assert_tagging_is_correct(json_input, expected_structural_characters)
    assert_strictly_increasing(
        parser.structural_indexes, parser.n_structural_indexes
    )
    detected_structural_characters = String(
        " " * len(expected_structural_characters)
    )
    for i in range(parser.n_structural_indexes):
        detected_structural_characters._buffer[
            Int(parser.structural_indexes[i])
        ] = ord("1")

    if detected_structural_characters != expected_structural_characters:
        print("Error in the detected structural characters")
        print("First is expected, second is detected")
        print(len(detected_structural_characters))
        print(len(expected_structural_characters))
        print(json_input)
        print(expected_structural_characters + " expected")
        print(detected_structural_characters + " detected")
        raise Error("Detected and expected structural characters do not match")

    # 3 are leftover
    assert_equal(
        parser.structural_indexes[Int(parser.n_structural_indexes)],
        UInt32(len(json_input)),
    )
    assert_equal(
        parser.structural_indexes[Int(parser.n_structural_indexes) + 1],
        UInt32(len(json_input)),
    )
    assert_equal(
        parser.structural_indexes[Int(parser.n_structural_indexes) + 2],
        UInt32(0),
    )


def check_stage1(json_file: Path):
    print("testing", json_file)
    json_input_with_expected = json_file.read_text()
    a = json_input_with_expected.splitlines()
    json_input = a[0]
    expected_structural_characters = a[1]

    print(json_input)
    parser = DomParserImplementation()
    error_code = parser.stage1(json_input)
    assert_equal(error_code, 0, "unexpected error code")
    verify_expected_structural_characters(
        parser, expected_structural_characters, json_input
    )


def test_wrong_tagging():
    json_file = "wrong_tagging.json"
    with assert_raises(contains="l is not a structural character"):
        check_stage1(get_jsons_directory() / json_file)


def test_detect_incorrect_result():
    json_file = "detect_incorrect_result.json"
    with assert_raises(
        contains="Detected and expected structural characters do not match"
    ):
        check_stage1(get_jsons_directory() / json_file)


def test_simple_json():
    valid_jsons_directory = get_jsons_directory() / "valid"
    all_files = valid_jsons_directory.listdir()
    assert_true(len(all_files) > 5)
    for entry in valid_jsons_directory.listdir():
        actual_file = valid_jsons_directory / entry[]
        if actual_file.is_file():
            if entry[] == "escaping_very_long.json":
                continue
            check_stage1(actual_file)
