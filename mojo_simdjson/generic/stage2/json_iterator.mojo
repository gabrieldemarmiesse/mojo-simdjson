from memory import UnsafePointer
from ...include.generic.dom_parser_implementation import DomParserImplementation
from mojo_simdjson.errors import ErrorType
from .tape_builder import TapeBuilder
from sys.intrinsics import likely, unlikely


struct WalkState:
    alias document_start = 0
    alias object_begin = 1
    alias object_field = 2
    alias object_continue = 3
    alias scope_end = 4
    alias array_begin = 5
    alias array_value = 6
    alias array_continue = 7
    alias document_end = 8


struct JsonIterator:
    var buffer: UnsafePointer[UInt8]
    var next_structural: UnsafePointer[UInt32]
    var dom_parser: UnsafePointer[DomParserImplementation]
    var depth: UInt32

    fn __init__(
        out self,
        dom_parser: DomParserImplementation,
        start_structural_index: Int,
    ):
        self.buffer = dom_parser.buf
        self.next_structural = (
            dom_parser.structural_indexes.unsafe_ptr() + start_structural_index
        )
        self.dom_parser = UnsafePointer.address_of(dom_parser)
        self.depth = 0

    fn walk_document(mut self, mut visitor: TapeBuilder) -> ErrorType:
        walk_state = WalkState.document_start

        while True:
            if walk_state == WalkState.document_start:
                if self.at_eof():
                    return errors.EMPTY
                error_code = visitor.visit_document_start(self)
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
                        walk_state = WalkState.object_begin
                        continue
                elif value[] == ord("["):
                    if self.peek()[] == ord("]"):
                        error_code = visitor.visit_empty_array(self)
                        if error_code != errors.SUCCESS:
                            return error_code
                    else:
                        walk_state = WalkState.array_begin
                        continue
                else:
                    error_code = self.visit_root_primitive(visitor, value)
                    if error_code != errors.SUCCESS:
                        return error_code

                walk_state = WalkState.document_end
                continue

            elif walk_state == WalkState.object_begin:
                self.depth += 1
                if self.depth > self.dom_parser[].max_depth():
                    return errors.DEPTH_ERROR
                self.dom_parser[].is_array[int(self.depth)] = False
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
                walk_state = WalkState.object_field
                continue

            elif walk_state == WalkState.object_field:
                if unlikely(self.advance()[] != ord(":")):
                    # Missing colon after key in object
                    return errors.TAPE_ERROR
                value = self.advance()
                # This should be a switch statement
                if value[] == ord("{"):
                    if self.peek()[] == ord("}"):
                        _ = self.advance()
                        error_code = visitor.visit_empty_object(self)
                        if error_code != errors.SUCCESS:
                            return error_code
                    else:
                        walk_state = WalkState.object_begin
                        continue
                elif value[] == ord("["):
                    if self.peek()[] == ord("]"):
                        _ = self.advance()
                        error_code = visitor.visit_empty_array(self)
                        if error_code != errors.SUCCESS:
                            return error_code
                    else:
                        walk_state = WalkState.array_begin
                        continue
                else:
                    error_code = self.visit_primitive(visitor, value)
                    if error_code != errors.SUCCESS:
                        return error_code
                walk_state = WalkState.object_continue
                continue

            elif walk_state == WalkState.object_continue:
                # this should technically be a switch statement
                next_char = self.advance()[]
                if next_char == ord(","):
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
                    walk_state = WalkState.object_field
                    continue
                elif next_char == ord("}"):
                    error_code = visitor.visit_object_end(self)
                    if error_code != errors.SUCCESS:
                        return error_code
                    walk_state = WalkState.scope_end
                    continue
                else:
                    return errors.TAPE_ERROR

            elif walk_state == WalkState.scope_end:
                self.depth -= 1
                if self.depth == 0:
                    walk_state = WalkState.document_end
                    continue
                if self.dom_parser[].is_array[int(self.depth)]:
                    walk_state = WalkState.array_continue
                    continue
                walk_state = WalkState.object_continue
                continue

            elif walk_state == WalkState.array_begin:
                self.depth += 1
                if self.depth >= self.dom_parser[].max_depth():
                    # Exceeded max depth
                    return errors.DEPTH_ERROR
                self.dom_parser[].is_array[int(self.depth)] = True
                error_code = visitor.visit_array_start(self)
                if error_code != errors.SUCCESS:
                    return error_code
                error_code = visitor.increment_count(self)
                if error_code != errors.SUCCESS:
                    return error_code
                walk_state = WalkState.array_value
                continue

            elif walk_state == WalkState.array_value:
                value = self.advance()
                # this should technically be a switch statement
                if value[] == ord("{"):
                    if self.peek()[] == ord("}"):
                        _ = self.advance()
                        # Empty object
                        error_code = visitor.visit_empty_object(self)
                        if error_code != errors.SUCCESS:
                            return error_code
                    else:
                        walk_state = WalkState.object_begin
                        continue
                elif value[] == ord("["):
                    if self.peek()[] == ord("]"):
                        _ = self.advance()
                        # Empty array
                        error_code = visitor.visit_empty_array(self)
                        if error_code != errors.SUCCESS:
                            return error_code
                    else:
                        walk_state = WalkState.array_begin
                        continue
                else:
                    error_code = self.visit_primitive(visitor, value)
                    if error_code != errors.SUCCESS:
                        return error_code
                walk_state = WalkState.array_continue
                continue

            elif walk_state == WalkState.array_continue:
                # this should technically be a switch statement
                next_character = self.advance()[]
                if next_character == ord(","):
                    error_code = visitor.increment_count(self)
                    if error_code != errors.SUCCESS:
                        return error_code
                    walk_state = WalkState.array_value
                    continue
                elif next_character == ord("]"):
                    error_code = visitor.visit_array_end(self)
                    if error_code != errors.SUCCESS:
                        return error_code
                    walk_state = WalkState.scope_end
                    continue
                else:
                    return errors.TAPE_ERROR

            elif walk_state == WalkState.document_end:
                error_code = visitor.visit_document_end(self)
                if error_code != errors.SUCCESS:
                    return error_code
                self.dom_parser[].next_structural_index = UInt32(
                    int(self.next_structural)
                    - int(self.dom_parser[].structural_indexes.unsafe_ptr())
                )
                if (
                    self.dom_parser[].next_structural_index
                    != self.dom_parser[].n_structural_indexes
                ):
                    # More than one JSON value at the root of the document, or extra characters at the end of the JSON!
                    return errors.TAPE_ERROR
                return errors.SUCCESS

    fn peek(self) -> UnsafePointer[UInt8]:
        return self.buffer + self.next_structural[]

    fn advance(mut self) -> UnsafePointer[UInt8]:
        pointer_to_current = self.peek()
        self.next_structural += 1
        return pointer_to_current

    fn remaining_len(self) -> Int:
        return int(self.dom_parser[].length - (self.next_structural - 1)[])

    # not 100% sure about this one
    fn at_eof(self) -> Bool:
        return self.next_structural == self.dom_parser[].structural_indexes.unsafe_ptr() + int(
            self.dom_parser[].n_structural_indexes
        )

    fn at_beginning(self) -> Bool:
        return self.next_structural == self.dom_parser[].structural_indexes.unsafe_ptr()

    fn last_structural(self) -> UInt8:
        return self.buffer[
            int(
                self.dom_parser[].structural_indexes[
                    int(self.dom_parser[].n_structural_indexes - 1)
                ]
            )
        ]

    fn visit_root_primitive(
        mut self, mut visitor: TapeBuilder, pointer: UnsafePointer[UInt8]
    ) -> ErrorType:
        # this should technically be a switch statement
        value = pointer[]
        if value == ord('"'):
            return visitor.visit_root_string(self, pointer)
        elif value == ord("t"):
            return visitor.visit_root_true_atom(self, pointer)
        elif value == ord("f"):
            return visitor.visit_root_false_atom(self, pointer)
        elif value == ord("n"):
            return visitor.visit_root_null_atom(self, pointer)
        elif value == ord("-") or (UInt8(ord("0")) <= value <= UInt8(ord("9"))):
            return visitor.visit_root_number(self, pointer)
        else:
            _ = value
            return errors.TAPE_ERROR

    fn visit_primitive(
        mut self, mut visitor: TapeBuilder, pointer: UnsafePointer[UInt8]
    ) -> ErrorType:
        # this should technically be a switch statement
        value = pointer[]
        # Use the fact that most scalars are going to be either strings or numbers.
        if value == ord('"'):
            return visitor.visit_string(self, pointer)
        elif value == ord("-") or (UInt8(ord("0")) <= value <= UInt8(ord("9"))):
            return visitor.visit_number(self, pointer)

        # true, false, null are uncommon.
        # This should technically be a switch statement
        if value == ord("t"):
            return visitor.visit_true_atom(self, pointer)
        elif value == ord("f"):
            return visitor.visit_false_atom(self, pointer)
        elif value == ord("n"):
            return visitor.visit_null_atom(self, pointer)
        else:
            return errors.TAPE_ERROR
