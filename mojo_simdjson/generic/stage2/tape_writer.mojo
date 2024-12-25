from memory import UnsafePointer
from ...include.internal.tape_type import TapeType
from ...include.internal import tape_type


struct TapeWriter:
    var next_tape_loc: UnsafePointer[UInt64]

    fn __init__(out self, tape: UnsafePointer[UInt64]):
        self.next_tape_loc = tape

    fn append_s64(inout self, value: Int64):
        self.append2(0, value.cast[DType.uint64](), tape_type.INT64)

    fn append_u64(inout self, value: UInt64):
        self.append(0, tape_type.UINT64)
        self.next_tape_loc[] = value
        self.next_tape_loc += 1

    # TODO: Is this type cast correct?
    fn append_double(inout self, value: Float64):
        self.append2(0, value.cast[DType.uint64](), tape_type.DOUBLE)

    fn skip(inout self):
        self.next_tape_loc += 1

    fn skip_large_integer(inout self):
        self.next_tape_loc += 2

    fn skip_double(inout self):
        self.next_tape_loc += 2

    fn append(inout self, value: UInt64, value_type: TapeType):
        self.next_tape_loc[] = value | (value_type.cast[DType.uint64]() << 56)
        self.next_tape_loc += 1

    # TODO: add a parameter?
    fn append2(inout self, value: UInt64, value2: UInt64, value_type: TapeType):
        self.append(value, value_type)
        self.next_tape_loc[] = value2
        self.next_tape_loc += 1

    @staticmethod
    fn write(tape_loc: UnsafePointer[UInt64], value: UInt64, value_type: TapeType):
        tape_loc[] = value | (value_type.cast[DType.uint64]() << 56)
