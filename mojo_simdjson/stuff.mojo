from memory.unsafe import pack_bits
from sys import llvm_intrinsic


fn eq[character: String](a: SIMD[DType.uint8, 64]) -> UInt64:
    alias splat_character = SIMD[DType.uint8, 64](ord(character))
    equality_mask = a == splat_character
    return pack_bits(equality_mask)


fn prefix_xor(bytes: UInt64) -> UInt64:
    result = llvm_intrinsic[
        "llvm.x86.pclmulqdq", SIMD[DType.uint64, 2], has_side_effect=False
    ](UInt64(0).join(bytes), ~SIMD[DType.uint64, 2](0), Int8(0x11))
    return result[1]
