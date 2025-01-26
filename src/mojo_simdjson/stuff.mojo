from memory.unsafe import pack_bits
from sys import llvm_intrinsic
import bit

fn eq[character: String](a: SIMD[DType.uint8, 64]) -> UInt64:
    alias splat_character = SIMD[DType.uint8, 64](ord(character))
    equality_mask = a == splat_character
    return pack_bits(equality_mask)

# this implementation is incorrect when pop_count is odd
fn prefix_xor_old(bytes: UInt64) -> UInt64:
    result = llvm_intrinsic[
        "llvm.x86.pclmulqdq", SIMD[DType.uint64, 2], has_side_effect=False
    ](UInt64(0).join(bytes), ~SIMD[DType.uint64, 2](0), Int8(0x11))
    return result[1]

# TODO: implement this for each architecture
fn prefix_xor(bits: UInt64) -> UInt64:
    result = UInt64(0)

    for i in range(64):
        b = bit.pop_count(bits << 64 - i - 1) % 2
        result |= (b << i)

    return result
