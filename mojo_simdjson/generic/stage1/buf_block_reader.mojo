from memory import Span, UnsafePointer, memset, memcpy
from collections import InlineArray

struct BufferBlockReader[step_size: Int, origin: Origin]:
    var buffer: Span[UInt8, origin]
    var len_minus_step: Int
    var idx: Int

    fn __init__(out self: Self, buffer: Span[UInt8, origin]):
        self.buffer = buffer
        if len(buffer) < Self.step_size:
            self.len_minus_step = 0
        else:
            self.len_minus_step = len(buffer) - Self.step_size
        self.len_minus_step = len(buffer) - Self.step_size
        self.idx = 0

    fn block_index(self) -> Int:
        return self.idx
    
    fn has_full_block(self) -> Bool:
        return self.idx < self.len_minus_step

    fn full_block(self) -> Span[UInt8, origin]:
        return self.buffer[self.idx: self.idx + Self.step_size]
    
    fn get_remainder(self, destination: UnsafePointer[UInt8]) -> Int:
        if len(self.buffer) == self.idx:
            return 0
        memcpy(destination, self.buffer[self.idx:].unsafe_ptr(), len(self.buffer) - self.idx)
        return len(self.buffer) - self.idx

    fn advance(inout self):
        self.idx += Self.step_size
        

        

    