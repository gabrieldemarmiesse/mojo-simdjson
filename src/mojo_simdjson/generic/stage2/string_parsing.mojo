from memory import UnsafePointer
from mojo_simdjson.include.haswell.stringparsing_defs import BackslashAndQuote
from mojo_simdjson.include.generic import jsoncharutils
from collections import InlineArray

# TODO: compute it at compile-time, let's avoid magic tables
alias escape_map = InlineArray[UInt8, 256](
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,  # 0x0.
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0x22,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0x2F,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,  # 0x4.
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0x5C,
    0,
    0,
    0,  # 0x5.
    0,
    0,
    0x08,
    0,
    0,
    0,
    0x0C,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0x0A,
    0,  # 0x6.
    0,
    0,
    0x0D,
    0,
    0x09,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,  # 0x7.
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
)


fn handle_unicode_codepoint(
    src_ptr: UnsafePointer[UnsafePointer[UInt8]],
    dst_ptr: UnsafePointer[UnsafePointer[UInt8]],
    allow_replacement: Bool,
) -> Bool:
    """Handle a unicode codepoint.

    Write appropriate values into dest
    src will advance 6 bytes or 12 bytes
    dest will advance a variable amount (return via pointer)
    return true if the unicode codepoint was valid
    We work in little-endian then swap at write time
    """
    # Use the default Unicode Character 'REPLACEMENT CHARACTER' (U+FFFD)
    alias substitution_code_point = UInt32(0xFFFD)

    # jsoncharutils.hex_to_u32_nocheck fills high 16 bits of the return value with 1s if the
    # conversion is not valid; we defer the check for this to inside the
    # multilingual plane check.
    code_point = jsoncharutils.hex_to_u32_nocheck(src_ptr[0] + 2)
    src_ptr[0] += 6

    # If we found a high surrogate, we must
    # check for low surrogate for characters
    # outside the Basic Multilingual Plane.
    if code_point >= 0xD800 and code_point < 0xDC00:
        src_data = src_ptr[0]
        # Compiler optimizations convert this to a single 16-bit load and compare on most platforms in C++
        # Not sure if this is the case in Mojo. We might have to check.
        alias backslash_u_as_simd = SIMD[DType.uint8, 2](ord("\\"), ord("u"))

        if not all(src_data.load[width=2]() == backslash_u_as_simd):
            if not allow_replacement:
                return False
            code_point = substitution_code_point
        else:
            code_point_2 = jsoncharutils.hex_to_u32_nocheck(src_data + 2)

            # We have already checked that the high surrogate is valid and
            # (code_point - 0xd800) < 1024.
            #
            # Check that code_point_2 is in the range 0xdc00..0xdfff
            # and that code_point_2 was parsed from valid hex.
            low_bit = code_point_2 - 0xDC00
            if low_bit >> 10:
                if not allow_replacement:
                    return False
                code_point = substitution_code_point
            else:
                code_point = (((code_point - 0xD800) << 10) | low_bit) + 0x10000
                src_ptr[0] += 6

    elif code_point >= 0xDC00 and code_point <= 0xDFFF:
        # If we encounter a low surrogate (not preceded by a high surrogate)
        # then we have an error.
        if not allow_replacement:
            return False
        code_point = substitution_code_point
    offset = jsoncharutils.codepoint_to_utf8(code_point, dst_ptr[0])
    dst_ptr[0] += offset
    return offset > 0


# The first argument is strange here. It's modified,
# but in the function call it's given a temporary variable,
# so any modification is lost. To represent that, I set
# the first argument as owned (same as mut but not visible from outside).
fn parse_string(
    owned src: UnsafePointer[UInt8],
    mut dst: UnsafePointer[UInt8],
    allow_replacement: Bool,
) -> UnsafePointer[UInt8]:
    """Unescape a valid UTF-8 string from src to dst, stopping at a final unescaped quote.
    There must be an unescaped quote terminating the string. It returns the final output
    position as pointer. In case of error (e.g., the string has bad escaped codes),
    then null_ptr is returned. It is assumed that the output buffer is large
    enough. E.g., if src points at 'joe"', then dst needs to have four free bytes +
    SIMDJSON_PADDING bytes.
    """
    while True:
        # Copy the next n bytes, and find the backslash and quote in them.
        backslash_quote = BackslashAndQuote.copy_and_find(src, dst)
        # If the next thing is the end quote, copy and return
        if backslash_quote.has_quote_first():
            # we encountered quotes first. Move dst to point to quotes and exit
            return dst + backslash_quote.quote_index()
        if backslash_quote.has_backslash():
            # find out where the backspace is
            backslash_dist = backslash_quote.backslash_index()
            escape_char = src[backslash_dist + 1]
            # we encountered backslash first. Handle backslash
            if escape_char == ord("u"):
                # move src/dst up to the start; they will be further adjusted
                # within the unicode codepoint handling code.
                src += backslash_dist
                dst += backslash_dist
                if not handle_unicode_codepoint(
                    UnsafePointer.address_of(src),
                    UnsafePointer.address_of(dst),
                    allow_replacement,
                ):
                    return UnsafePointer[UInt8]()
            else:
                # simple 1:1 conversion. Will eat bs_dist+2 characters in input and
                # write bs_dist+1 characters to output
                # note this may reach beyond the part of the buffer we've actually
                # seen. I think this is ok
                escape_result = escape_map[Int(escape_char)]
                if escape_result == 0:
                    return UnsafePointer[
                        UInt8
                    ]()  # bogus escape value is an error
                dst[backslash_dist] = escape_result
                src += backslash_dist + 2
                dst += backslash_dist + 1
        else:
            # they are the same. Since they can't co-occur, it means we
            # encountered neither.
            src += BackslashAndQuote.BYTES_PROCESSED
            dst += BackslashAndQuote.BYTES_PROCESSED
