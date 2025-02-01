from .json_escape_scanner import JsonEscapeScanner
from ...stuff import eq, prefix_xor
from memory.unsafe import bitcast
from ... import errors
from ...debug import bin_display_reverse
from ...globals import TRACING_ENABLED


@value
struct JsonStringBlock:
    var _escaped: UInt64
    var _quote: UInt64
    var _in_string: UInt64

    fn __init__(mut self, escaped: UInt64, quote: UInt64, in_string: UInt64):
        self._escaped = escaped
        self._quote = quote
        self._in_string = in_string

    @always_inline
    fn escaped(self) -> UInt64:
        return self._escaped

    @always_inline
    fn quote(self) -> UInt64:
        return self._quote

    @always_inline
    fn string_content(self) -> UInt64:
        return self._in_string & ~self._quote

    @always_inline
    fn non_quote_inside_string(self, mask: UInt64) -> UInt64:
        return mask & self._in_string

    @always_inline
    fn non_quote_outside_string(self, mask: UInt64) -> UInt64:
        return mask & ~self._in_string

    @always_inline
    fn string_tail(self) -> UInt64:
        value = self._in_string ^ self._quote
        bin_display_reverse(value, "string_tail")
        return value


struct JsonStringScanner:
    var escape_scanner: JsonEscapeScanner
    var prev_in_string: UInt64

    fn __init__(out self):
        self.escape_scanner = JsonEscapeScanner()
        self.prev_in_string = 0

    fn next(mut self, in_: SIMD[DType.uint8, 64]) -> JsonStringBlock:
        backslash = eq["\\"](in_)
        escaped = self.escape_scanner.next(backslash).escaped
        quote = eq['"'](in_) & ~escaped
        in_string = prefix_xor(quote) ^ self.prev_in_string
        self.prev_in_string = bitcast[DType.uint64](
            (bitcast[DType.int64](in_string) >> 63)
        )
        bin_display_reverse(escaped, "escaped")
        bin_display_reverse(quote, "quote")
        bin_display_reverse(prefix_xor(quote), "prefix_xor(quote)")
        bin_display_reverse(in_string, "in_string")
        bin_display_reverse(self.prev_in_string, "prev_in_string")

        return JsonStringBlock(escaped, quote, in_string)

    fn finish(self) -> errors.ErrorType:
        if self.prev_in_string:
            return errors.UNCLOSED_STRING
        return errors.SUCCESS
