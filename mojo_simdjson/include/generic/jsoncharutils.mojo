
from mojo_simdjson.internal.jsoncharutils_tables import structural_or_whitespace
from collections import InlineArray


fn negate_inlinearray(array: InlineArray[UInt8, 256]) -> InlineArray[UInt8, 256]:
    var result = InlineArray[UInt8, 256](0)
    for i in range(256):
        result[i] = 1 - array[i]
    return result


@always_inline
fn is_not_structural_or_whitespace(c: UInt8) -> UInt32:
    alias structural_or_whitespace_negated = negate_inlinearray(structural_or_whitespace)
    return structural_or_whitespace_negated.unsafe_get(int(c)).cast[DType.uint32]()


@always_inline
fn is_structural_or_whitespace(c: UInt8) -> UInt32:
    return structural_or_whitespace.unsafe_get(int(c)).cast[DType.uint32]()
