from mojo_simdjson.internal.jsoncharutils_tables import (
    structural_or_whitespace,
    digit_to_val32,
)
from collections import InlineArray
from memory import UnsafePointer


fn negate_inlinearray(
    array: InlineArray[UInt8, 256]
) -> InlineArray[UInt8, 256]:
    var result = InlineArray[UInt8, 256](0)
    for i in range(256):
        result[i] = 1 - array[i]
    return result


@always_inline
fn is_not_structural_or_whitespace(c: UInt8) -> UInt32:
    alias structural_or_whitespace_negated = negate_inlinearray(
        structural_or_whitespace
    )
    return structural_or_whitespace_negated.unsafe_get(Int(c)).cast[
        DType.uint32
    ]()


@always_inline
fn is_structural_or_whitespace(c: UInt8) -> UInt32:
    return structural_or_whitespace.unsafe_get(Int(c)).cast[DType.uint32]()


fn hex_to_u32_nocheck(src: UnsafePointer[UInt8]) -> UInt32:
    """Returns a value with the high 16 bits set if not valid.

    otherwise returns the conversion of the 4 hex digits at src into the bottom
    16 bits of the 32-bit return register, see
    https://lemire.me/blog/2019/04/17/parsing-short-hexadecimal-strings-efficiently/
    """
    v1 = digit_to_val32[630 + Int(src[0])]
    v2 = digit_to_val32[420 + Int(src[1])]
    v3 = digit_to_val32[210 + Int(src[2])]
    v4 = digit_to_val32[0 + Int(src[3])]
    return v1 | v2 | v3 | v4


fn codepoint_to_utf8(cp: UInt32, c: UnsafePointer[UInt8]) -> Int:
    """Given a code point cp, writes to c
    the utf-8 code, outputting the length in
    bytes, if the length is zero, the code point
    is invalid.

    This can possibly be made faster using pdep
    and clz and table lookups, but JSON documents
    have few escaped code points, and the following
    function looks cheap.
    """
    if cp <= 0x7F:
        c[0] = cp.cast[DType.uint8]()
        return 1  # ascii
    if cp <= 0x7FF:
        c[0] = ((cp >> 6) + 192).cast[DType.uint8]()
        c[1] = ((cp & 63) + 128).cast[DType.uint8]()
        return 2  # universal plane
        # Surrogates are treated elsewhere...
        # } //else if (0xd800 <= cp && cp <= 0xdfff) {
        # return 0; // surrogates // could put assert here
    elif cp <= 0xFFFF:
        c[0] = ((cp >> 12) + 224).cast[DType.uint8]()
        c[1] = (((cp >> 6) & 63) + 128).cast[DType.uint8]()
        c[2] = ((cp & 63) + 128).cast[DType.uint8]()
        return 3
    elif cp <= 0x10FFFF:  # if you know you have a valid code point, this
        # is not needed
        c[0] = ((cp >> 18) + 240).cast[DType.uint8]()
        c[1] = (((cp >> 12) & 63) + 128).cast[DType.uint8]()
        c[2] = (((cp >> 6) & 63) + 128).cast[DType.uint8]()
        c[3] = ((cp & 63) + 128).cast[DType.uint8]()
        return 4
    # will return 0 when the code point was too large.
    return 0  # bad r
