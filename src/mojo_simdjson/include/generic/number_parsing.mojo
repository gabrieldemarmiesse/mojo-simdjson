from memory import UnsafePointer
from mojo_simdjson.generic.stage2.tape_writer import TapeWriter
from mojo_simdjson.include.generic.jsoncharutils import (
    is_not_structural_or_whitespace,
)
from mojo_simdjson import errors
from utils import StringSlice
from memory import Span

alias ord_minus_sign = UInt8(ord("-"))
alias ord_0 = UInt8(ord("0"))
alias ord_9 = UInt8(ord("9"))
alias ord_dot = UInt8(ord("."))
alias ord_e = UInt8(ord("e"))
alias ord_E = UInt8(ord("E"))


fn is_digit(c: UInt8) -> Bool:
    return UInt8(ord("0")) <= c <= UInt8(ord("9"))


fn parse_number(
    src: UnsafePointer[UInt8], mut writer: TapeWriter
) -> errors.ErrorType:
    # This function has significant changes compared to
    # the original version in simdjson. The original version
    # has custom code for parsing numbers, notably because
    # the custom code is faster than the stdlib.
    # However in Mojo it's much simpler to change the stdlib
    # and improve it. So if we notice a performance issue/improvement
    # in the future, we can just change the stdlib and it will be
    # reflected in in mojo-simdjson as well.

    # We need to
    # 1) identify if we are working with a float or an integer
    # 2) find when the number ends
    # 3) create a StringSlice from this data
    # 4) call the stdlib to parse the number
    # 5) write the number to the tape

    # check for minus sign
    has_minus_sign = src[0] == ord_minus_sign
    p = src + Int(has_minus_sign)

    while is_digit(p[0]):
        p += 1

    var is_float: Bool
    if p[0] == ord_dot or p[0] == ord_e or p[0] == ord_E:
        is_float = True
        # we still need to go on to find the end of the number
        # TODO: avoid reading beyond the end of the buffer here in case we're a single atom in the file
        while is_not_structural_or_whitespace(p[0]):
            p += 1

    elif is_not_structural_or_whitespace(p[0]):
        return errors.NUMBER_ERROR
    else:
        is_float = False

    length = Int(p) - Int(src)
    # can we avoid going through span?
    span = Span(src, length)
    string_slice = StringSlice(unsafe_from_utf8=span)
    if is_float:
        try:
            number_as_float = Float64(string_slice)
        except ValueError:
            return errors.NUMBER_ERROR
        else:
            writer.append_double(number_as_float)
    else:
        try:
            number_as_int = Int(string_slice)
        except ValueError:
            return errors.NUMBER_ERROR
        else:
            writer.append_s64(number_as_int)

    return errors.SUCCESS
