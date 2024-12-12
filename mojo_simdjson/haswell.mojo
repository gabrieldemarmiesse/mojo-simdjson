from .generic.json_character_block import JsonCharacterBlock
from memory.unsafe import pack_bits
from .debug import bin_display_reverse


fn repeat_until[initial_size: Int, //, target_size: Int](in_: SIMD[DType.uint8, initial_size]
) -> SIMD[DType.uint8, target_size]:
    constrained[initial_size <= target_size, "initial size should be smaller than target size"]()
    @parameter
    if initial_size == target_size:
        return rebind[SIMD[DType.uint8, target_size]](in_)
    else:
        new_vector = in_.join(in_)
        return repeat_until[target_size](new_vector)


fn classify(in_: SIMD[DType.uint8, 64]) -> JsonCharacterBlock:
    alias whitespace_table = repeat_until[32](SIMD[DType.uint8, 16](
        ord(' '), 100, 100, 100, 17, 100, 113, 2, 100, ord('\t'), ord('\n'), 112, 100, ord('\r'), 100, 100))
    
    alias op_table = repeat_until[32](SIMD[DType.uint8, 16](
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, ord(':'), ord('{'), # : = 3A, [ = 5B, { = 7B
        ord(','), ord('}'), 0, 0  # , = 2C, ] = 5D, } = 7D
    ))

    whitespace = pack_bits(in_ == whitespace_table._dynamic_shuffle(in_))

    curlified = in_ | 0x20

    op = pack_bits(curlified == op_table._dynamic_shuffle(in_))

    bin_display_reverse(whitespace, "whitespace")
    bin_display_reverse(op, "op")

    return JsonCharacterBlock(whitespace, op)


