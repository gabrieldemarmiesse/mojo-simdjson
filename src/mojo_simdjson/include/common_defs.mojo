"""
// Align to N-byte boundary
#define SIMDJSON_ROUNDUP_N(a, n) (((a) + ((n)-1)) & ~((n)-1))
#define SIMDJSON_ROUNDDOWN_N(a, n) ((a) & ~((n)-1))
"""


@always_inline
fn simdjson_roundup_n(a: Int, n: Int) -> Int:
    return ((a) + ((n) - 1)) & ~((n) - 1)


@always_inline
fn simdjson_rounddown_n(a: Int, n: Int) -> Int:
    return (a) & ~((n) - 1)
