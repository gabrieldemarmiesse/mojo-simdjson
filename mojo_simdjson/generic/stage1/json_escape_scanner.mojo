from ...globals import SIMDJSON_SKIP_BACKSLASH_SHORT_CIRCUIT

alias ODD_BITS = 0xAAAAAAAAAAAAAAAA  # TODO: verify this value or generate at compile time


@value
struct _EscapedAndEscape:
    var escaped: UInt64
    var escape: UInt64


struct JsonEscapeScanner:
    var next_is_escaped: UInt64

    fn __init__(out self: Self):
        self.next_is_escaped = 0

    fn next(inout self, backslash: UInt64) -> _EscapedAndEscape:
        @parameter
        if not SIMDJSON_SKIP_BACKSLASH_SHORT_CIRCUIT:
            if not backslash:
                return _EscapedAndEscape(
                    self.next_escaped_without_backslashes(), 0
                )

        escape_and_terminal_code = self.next_escape_and_terminal_code(
            backslash & ~self.next_is_escaped
        )
        escaped = escape_and_terminal_code ^ (backslash | self.next_is_escaped)
        escape = escape_and_terminal_code & backslash
        self.next_is_escaped = escape >> 63
        return _EscapedAndEscape(escaped, escape)

    fn next_escaped_without_backslashes(inout self) -> UInt64:
        escaped = self.next_is_escaped
        self.next_is_escaped = 0
        return escaped

    fn next_escape_and_terminal_code(self, potential_escape: UInt64) -> UInt64:
        maybe_escaped = UInt64(potential_escape << 1)
        maybe_escaped_and_odd_bits = maybe_escaped | ODD_BITS
        even_series_codes_and_odd_bits = (
            maybe_escaped_and_odd_bits - potential_escape
        )
        return even_series_codes_and_odd_bits ^ ODD_BITS
