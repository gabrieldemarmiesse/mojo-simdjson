struct Document:
    var tape: List[UInt64]
    var string_buf: List[UInt8]

    fn __init__(out self: Self):
        self.tape = List[UInt64]()
        self.string_buf = List[UInt8]()

    fn __moveinit__(out self: Self, owned other: Self):
        self.tape = other.tape^
        self.string_buf = other.string_buf^
