from memory import UnsafePointer
from ...include.generic.dom_parser_implementation import DomParserImplementation
from mojo_simdjson.errors import ErrorType
from .tape_builder import TapeBuilder


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


    # so here we're supposed to have a finite state machine with 
    # goto statements left and right. Since we don't have goto
    # statements in Mojo (as far as I know), we're going with a recursive
    # approach. There is a tradeoff here, as we might get a recursion limit
    # earlier, but we have more data on the stack so it's slightly easier 
    # to manage memory. Also, with goto, we wouldn't pay the cost of function calls
    # and returns, so that plays a role.
    fn walk_document(self, visitor: TapeBuilder) -> ErrorType:
        if self.at_eof():
            return errors.EMPTY

    fn object_begin(self) -> ErrorType:
        pass

    fn object_field(self) -> ErrorType:
        pass
    
    fn object_continue(self) -> ErrorType:
        pass
    
    fn scope_end(self) -> ErrorType:
        pass

    fn array_begin(self) -> ErrorType:
        pass
    
    fn array_value(self) -> ErrorType:
        pass
    
    fn array_continue(self) -> ErrorType:
        pass
    
    fn document_end(self) -> ErrorType:
        pass

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

    
    fn visit_root_primitive(inout self, inout visitor: TapeBuilder, pointer: UnsafePointer[UInt8]) -> ErrorType:
        # this should technically be a switch statement
        value = pointer[]
        if value == ord('"'):
            return visitor.visit_root_string(self, pointer)
        elif value == ord('t'):
            return visitor.visit_root_true_atom(self, pointer)
        elif value == ord('f'):
            return visitor.visit_root_false_atom(self, pointer)
        elif value == ord('n'):
            return visitor.visit_root_null_atom(self, pointer)
        elif value == ord('-') or (UInt8(ord('0')) <= value <= UInt8(ord('9'))):
            return visitor.visit_root_number(self, pointer)
        else:
            return errors.TAPE_ERROR


    fn visit_primitive(inout self, inout visitor: TapeBuilder, pointer: UnsafePointer[UInt8]) -> ErrorType:
        # this should technically be a switch statement
        value = pointer[]
        # Use the fact that most scalars are going to be either strings or numbers.
        if value == ord('"'):
            return visitor.visit_string(self, pointer)
        elif value == ord('-') or (UInt8(ord('0')) <= value <= UInt8(ord('9'))):
            return visitor.visit_number(self, pointer)
        
        # true, false, null are uncommon.
        # This should technically be a switch statement
        if value == ord('t'):
            return visitor.visit_true_atom(self, pointer)
        elif value == ord('f'):
            return visitor.visit_false_atom(self, pointer)
        elif value == ord('n'):
            return visitor.visit_null_atom(self, pointer)
        else:
            return errors.TAPE_ERROR
