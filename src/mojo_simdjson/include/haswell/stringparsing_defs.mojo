from bit import count_trailing_zeros
from memory import UnsafePointer
from mojo_simdjson.globals import SIMDJSON_PADDING
from memory.unsafe import pack_bits


@value
@register_passable
struct BackslashAndQuote:
    alias BYTES_PROCESSED = 32

    var backslash_bits: UInt32
    var quote_bits: UInt32

    fn has_quote_first(self) -> Bool:
        return (self.backslash_bits - 1) & self.quote_bits != 0

    fn has_backslash(self) -> Bool:
        return (self.quote_bits - 1) & self.backslash_bits != 0

    fn quote_index(self) -> Int:
        return Int(count_trailing_zeros(self.quote_bits))

    fn backslash_index(self) -> Int:
        return Int(count_trailing_zeros(self.backslash_bits))

    @staticmethod
    fn copy_and_find(
        src: UnsafePointer[UInt8], dst: UnsafePointer[UInt8]
    ) -> BackslashAndQuote:
        # this can read up to 15 bytes beyond the buffer size, but we require
        # SIMDJSON_PADDING of padding
        constrained[
            SIMDJSON_PADDING >= (Self.BYTES_PROCESSED - 1),
            "Backslash and quote finder must process fewer than SIMDJSON_PADDING bytes",
        ]()
        v = src.load[width=8]()
        # store to dest unconditionally - we can overwrite the bits we don't like later
        dst.store(v)
        return BackslashAndQuote(
            backslash_bits=pack_bits(v == UInt8(ord("\\"))).cast[DType.uint32](),
            quote_bits=pack_bits(v == UInt8(ord('"'))).cast[DType.uint32](),
        )
