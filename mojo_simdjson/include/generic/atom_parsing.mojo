
from memory import UnsafePointer
from memory import bitcast
from mojo_simdjson.include.generic.jsoncharutils import is_not_structural_or_whitespace

alias true_as_simd = SIMD[DType.uint8, 4](ord("t"), ord("r"), ord("u"), ord("e"))
alias alse_as_simd = SIMD[DType.uint8, 4](ord("a"), ord("l"), ord("s"), ord("e"))
alias null_as_simd = SIMD[DType.uint8, 4](ord("n"), ord("u"), ord("l"), ord("l"))


# TODO: use StringLiteral instead of SIMD, it's cleaner
@always_inline
fn str4ncmp[reference: SIMD[DType.uint8, 4]](start_of_4: UnsafePointer[UInt8]) -> UInt32:
    """Returns 0 if the 4 bytes starting at start_of_4 are equal to reference, returns any
    other value otherwise.
    """
    alias reference_as_uint32 = bitcast[DType.uint32, new_width=1](reference)
    four_bytes_as_uint32 = bitcast[DType.uint32, new_width=1](start_of_4.load[width=4]())
    return four_bytes_as_uint32 ^ reference_as_uint32


fn is_valid_true_atom(src: UnsafePointer[UInt8]) -> Bool:
    check_as_uint32 = str4ncmp[true_as_simd](src) | is_not_structural_or_whitespace(src[4])
    return check_as_uint32 == 0


fn is_valid_true_atom(src: UnsafePointer[UInt8], length: Int) -> Bool:
    if length > 4:
        return is_valid_true_atom(src)
    elif length == 4:
        return str4ncmp[true_as_simd](src) == 0
    else:
        return False


# + 1 on the pointer here because we check only 4 bytes, and we already know the first byte is 'f'
fn is_valid_false_atom(src: UnsafePointer[UInt8]) -> Bool:
    check_as_uint32 = str4ncmp[alse_as_simd](src + 1) | is_not_structural_or_whitespace(src[5])
    return check_as_uint32 == 0


fn is_valid_false_atom(src: UnsafePointer[UInt8], length: Int) -> Bool:
    if length > 5:
        return is_valid_false_atom(src)
    elif length == 5:
        return str4ncmp[alse_as_simd](src + 1) == 0
    else:
        return False


fn is_valid_null_atom(src: UnsafePointer[UInt8]) -> Bool:
    check_as_uint32 = str4ncmp[null_as_simd](src) | is_not_structural_or_whitespace(src[4])
    return check_as_uint32 == 0


fn is_valid_null_atom(src: UnsafePointer[UInt8], length: Int) -> Bool:
    if length > 4:
        return is_valid_null_atom(src)
    elif length == 4:
        return str4ncmp[null_as_simd](src) == 0
    else:
        return False
