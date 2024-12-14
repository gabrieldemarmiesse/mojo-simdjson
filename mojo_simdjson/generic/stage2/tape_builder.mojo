from memory import UnsafePointer
from ... import errors
from ...include.generic.dom_parser_implementation import DomParserImplementation
from ...include.dom.document import Document
from .json_iterator import JsonIterator
from .tape_writer import TapeWriter

struct TapeBuilder:
    var tape: TapeWriter
    var current_string_buffer_loc: UnsafePointer[UInt8]


    fn __init__(out self, doc: Document):
        self.tape = TapeWriter(doc.tape.unsafe_ptr())
        self.current_string_buffer_loc = doc.string_buf.unsafe_ptr()

    # TODO: add streaming
    @staticmethod
    fn parse_document(inout dom_parser: DomParserImplementation, owned document: Document) -> errors.ErrorType:
        
        dom_parser.document = document^
        iter_ = JsonIterator(dom_parser, 0)
        builder = TapeBuilder(dom_parser.document)
        return iter_.walk_document(builder)