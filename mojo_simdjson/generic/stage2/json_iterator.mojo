from memory import UnsafePointer
from ...include.generic.dom_parser_implementation import DomParserImplementation


struct JsonIterator:
    var buffer: UnsafePointer[UInt8]
    var next_structural: UInt32
    var dom_parser: UnsafePointer[DomParserImplementation]
    var depth: UInt32

    fn __init__(out self, dom_parser: DomParserImplementation, start_structural_index: Int):
        self.buffer = dom_parser.buf
        self.next_structural = dom_parser.structural_indexes[start_structural_index]
        self.dom_parser = UnsafePointer.address_of(dom_parser)
        self.depth = 0
    


    fn visit_root_primitive()