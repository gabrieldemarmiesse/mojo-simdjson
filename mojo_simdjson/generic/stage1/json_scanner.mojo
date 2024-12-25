from .json_string_scanner import JsonStringBlock, JsonStringScanner
from ..json_character_block import JsonCharacterBlock
from memory import UnsafePointer
from ...debug import bin_display_reverse


struct JsonBlock:
    var _string: JsonStringBlock
    var _characters: JsonCharacterBlock
    var _follows_potential_nonquote_scalar: UInt64

    fn __init__(
        out self: Self,
        owned strings: JsonStringBlock,
        characters: JsonCharacterBlock,
        follows_potential_nonquote_scalar: UInt64,
    ):
        self._string = strings^
        self._characters = characters
        self._follows_potential_nonquote_scalar = follows_potential_nonquote_scalar

    @always_inline
    fn structural_start(self) -> UInt64:
        return self.potential_structural_start() & ~self._string.string_tail()

    @always_inline
    fn whitespace(self) -> UInt64:
        return self.non_quote_outside_string(self._characters.whitespace())

    @always_inline
    fn non_quote_inside_string(self, mask: UInt64) -> UInt64:
        return self._string.non_quote_inside_string(mask)

    @always_inline
    fn non_quote_outside_string(self, mask: UInt64) -> UInt64:
        return self._string.non_quote_outside_string(mask)

    @always_inline
    fn potential_structural_start(self) -> UInt64:
        value = self._characters.op() | self.potential_scalar_start()
        bin_display_reverse(value, "potential_structural_start")
        return value

    @always_inline
    fn potential_scalar_start(self) -> UInt64:
        value = self._characters.scalar() & ~self.follows_potential_scalar()
        # bin_display_reverse(value, "potential_scalar_start")
        return value

    @always_inline
    fn follows_potential_scalar(self) -> UInt64:
        return self._follows_potential_nonquote_scalar


struct JsonScanner:
    var prev_scalar: UInt64
    var string_scanner: JsonStringScanner

    fn __init__(out self: Self):
        self.prev_scalar = 0
        self.string_scanner = JsonStringScanner()

    fn next(inout self, in_: SIMD[DType.uint8, 64]) -> JsonBlock:
        strings = self.string_scanner.next(in_)
        characters = JsonCharacterBlock.classify(in_)

        nonquote_scalar = characters.scalar() & ~strings.quote()
        follows_nonquote_scalar = follows(nonquote_scalar, self.prev_scalar)
        return JsonBlock(strings^, characters, follows_nonquote_scalar)

    fn finish(self) -> errors.ErrorType:
        return self.string_scanner.finish()


fn follows(match_: UInt64, inout overflow: UInt64) -> UInt64:
    result = match_ << 1 | overflow
    overflow = match_ >> 63
    return result
