from memory import UnsafePointer
from ...include.generic.dom_parser_implementation import DomParserImplementation
from mojo_simdjson.errors import ErrorType
from .tape_builder import TapeBuilder
from sys.intrinsics import likely, unlikely

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


    # So here we're supposed to have a finite state machine with 
    # goto statements left and right. Since we don't have goto
    # statements in Mojo (as far as I know), we're going with a recursive
    # approach. Note that this is not an optimal approach because 
    # it increase the stack size for every new structural character.
    # Meaning we can only process small jsons. We should rewrite it with loops.
    fn walk_document(self, visitor: TapeBuilder) -> ErrorType:
        if self.at_eof():
            return errors.EMPTY
        eror_code = visitor.visit_document_start(self)
        if error_code != errors.SUCCESS:
            return error_code
        
        value = self.advance()

        # This should be a switch statement
        if value[] == ord("{"):
            if self.last_structural() != ord("}"):
                return errors.TAPE_ERROR
        elif value[] == ord("["):
            if self.last_structural() != ord("]"):
                return errors.TAPE_ERROR
        
        if value[] == ord("{"):
            if self.peek()[] == ord("}"):
                error_code = visitor.visit_empty_object(self)
                if error_code != errors.SUCCESS:
                    return error_code
            else:
                return self.object_begin(visitor)
        elif value[] == ord("["):
            if self.peek()[] == ord("]"):
                error_code = visitor.visit_empty_array(self)
                if error_code != errors.SUCCESS:
                    return error_code
            else:
                return self.array_begin(visitor)
        else:
            error_code = self.visit_root_primitive(visitor, value)
            if error_code != errors.SUCCESS:
                return error_code
        
        return self.document_end(visitor)

    fn object_begin(self, visitor: TapeBuilder) -> ErrorType:
        self.depth += 1
        if self.depth > self.dom_parser[].max_depth:
            return errors.DEPTH_ERROR
        self.dom_parser.is_array[self.depth] = False
        error_code = visitor.visit_object_start(self)
        if error_code != errors.SUCCESS:
            return error_code

        key = self.advance()
        if key[] != ord('"'):
            # object must start with a key
            return errors.TAPE_ERROR
        error_code = visitor.increment_count(self)
        if error_code != errors.SUCCESS:
            return error_code
        error_code = visitor.visit_key(self, key)
        if error_code != errors.SUCCESS:
            return error_code
        return self.object_field(visitor)

    fn object_field(self, visitor: TapeBuilder) -> ErrorType:
        if unlikely(self.advance()[] != ord(":")):
            # Missing colon after key in object
            return errors.TAPE_ERROR
        
        value = self.advance()
        # This should be a switch statement
        if value[] == ord("{"):
            if self.peek()[] == ord("}"):
                self.advance()
                error_code = visitor.visit_empty_object(self)
                if error_code != errors.SUCCESS:
                    return error_code
            else:
                return self.object_begin(visitor)
        elif value[] == ord("["):
            if self.peek()[] == ord("]"):
                self.advance()
                error_code = visitor.visit_empty_array(self)
                if error_code != errors.SUCCESS:
                    return error_code
            else:
                return self.array_begin(visitor)
        else:
            error_code = self.visit_primitive(visitor, value)
            if error_code != errors.SUCCESS:
                return error_code

        return self.object_continue(visitor)

    fn object_continue(self, visitor: TapeBuilder) -> ErrorType:
        # this should technically be a switch statement
        value = self.advance()[]
        if value == ord(","):
            error_code = visitor.increment_count(self)
            if error_code != errors.SUCCESS:
                return error_code
            key = self.advance()
            if key[] != ord('"'):
                # Key string missing at beginning of field in object
                return errors.TAPE_ERROR
            error_code = visitor.visit_key(self, key)
            if error_code != errors.SUCCESS:
                return error_code
            return self.object_field(visitor)
        elif value == ord("}"):
            error_code = visitor.visit_object_end(self)
            if error_code != errors.SUCCESS:
                return error_code
            return self.scope_end(visitor)
        else:
            return errors.TAPE_ERROR

    fn scope_end(self, visitor: TapeBuilder) -> ErrorType:
        self.depth -= 1
        if self.depth == 0:
            return self.document_end(visitor)
        if self.dom_parser[].is_array[self.depth]:
            return self.array_continue(visitor)
        return self.object_continue(visitor)

    fn array_begin(self, visitor: TapeBuilder) -> ErrorType:
        self.depth += 1
        if self.depth >= self.dom_parser[].max_depth:
            # Exceeded max depth
            return errors.DEPTH_ERROR
        self.dom_parser[].is_array[self.depth] = True
        error_code = visitor.visit_array_start(self)
        if error_code != errors.SUCCESS:
            return error_code
        error_code = visitor.increment_count(self)
        if error_code != errors.SUCCESS:
            return error_code
        return self.array_value(visitor)

    fn array_value(self, visitor: TapeBuilder) -> ErrorType:
        value = self.advance()
        # this should technically be a switch statement
        if value[] == ord("{"):
            if self.peek()[] == ord("}"):
                self.advance()
                # Empty object
                error_code = visitor.visit_empty_object(self)
                if error_code != errors.SUCCESS:
                    return error_code
            else:
                return self.object_begin(visitor)
        elif value[] == ord("["):
            if self.peek()[] == ord("]"):
                self.advance()
                # Empty array
                error_code = visitor.visit_empty_array(self)
                if error_code != errors.SUCCESS:
                    return error_code
            else:
                return self.array_begin(visitor)
        else:
            error_code = self.visit_primitive(visitor, value)
            if error_code != errors.SUCCESS:
                return error_code
        return self.array_continue(visitor)

    fn array_continue(self, visitor: TapeBuilder) -> ErrorType:
        # this should technically be a switch statement
        value = self.advance()[]
        if value == ord(","):
            error_code = visitor.increment_count(self)
            if error_code != errors.SUCCESS:
                return error_code
            return self.array_value(visitor)
        elif value == ord("]"):
            error_code = visitor.visit_array_end(self)
            if error_code != errors.SUCCESS:
                return error_code
            return self.scope_end(visitor)
        else:
            return errors.TAPE_ERROR
    
    fn document_end(self, visitor: TapeBuilder) -> ErrorType:
        error_code = visitor.visit_document_end(self)
        if error_code != errors.SUCCESS:
            return error_code
        self.dom_parser[].next_structural_index = UInt32(self.next_structural - self.dom_parser[].structural_indexes.unsafe_ptr())
        if self.dom_parser[].next_structural_index != self.dom_parser[].n_structural_indexes:
            # More than one JSON value at the root of the document, or extra characters at the end of the JSON!
            return errors.TAPE_ERROR
        return errors.SUCCESS

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
