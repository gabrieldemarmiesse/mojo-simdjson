fn bin_display_reverse(input: UInt64, additional_info: String = ""):
    a = bin(input, prefix="")
    b = "0" * (64 - len(a)) + a
    print((b[::-1] + "   " + additional_info).replace("0", " "))
