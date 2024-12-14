from memory import UnsafePointer
from ...include.generic.dom_parser_implementation import DomParserImplementation


struct JsonIterator:
    var buffer: UnsafePointer[UInt8]
    var next_structural: UnsafePointer[UInt32]
    var dom_parser: UnsafePointer[DomParserImplementation]
    var depth: UInt32

    fn __init__(out self, dom_parser: DomParserImplementation, start_structural_index: Int):
        self.buffer = dom_parser.buf
        self.next_structural = dom_parser.structural_indexes.unsafe_ptr() + start_structural_index
        self.dom_parser = UnsafePointer.address_of(dom_parser)
        self.depth = 0

    fn peek(self) -> UnsafePointer[UInt8]:
        return self.buffer + self.next_structural[]

    fn advance(inout self) -> UnsafePointer[UInt8]:
        pointer_to_current = self.peek()
        self.next_structural += 1
        return pointer_to_current

    fn remaining_len(self) -> Int:
        return int(self.dom_parser[].length - (self.next_structural - 1)[])

    # not 100% sure about this one
    fn at_eof(self) -> Bool:
        return self.next_structural == self.dom_parser[].structural_indexes.unsafe_ptr() + int(self.dom_parser[].n_structural_indexes)
    
    fn at_beginning(self) -> Bool:
        return self.next_structural == self.dom_parser[].structural_indexes.unsafe_ptr()

    fn last_structural(self) -> UInt8:
        return self.buffer[int(self.dom_parser[].structural_indexes[int(self.dom_parser[].n_structural_indexes - 1)])]

    
