from .globals import TRACING_ENABLED


@always_inline
fn bin_display_reverse(input: UInt64, additional_info: String = ""):
    @parameter
    if TRACING_ENABLED:
        a = bin(input, prefix="")
        b = "0" * (64 - len(a)) + a
        print((b[::-1] + "   " + additional_info).replace("0", " "))
