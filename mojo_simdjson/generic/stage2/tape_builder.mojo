from memory import UnsafePointer
from ... import errors
from ...include.generic.dom_parser_implementation import DomParserImplementation
from ...include.dom.document import Document
from .json_iterator import JsonIterator
from .tape_writer import TapeWriter
from mojo_simdjson.include.generic import atom_parsing
from mojo_simdjson.include.internal import tape_type
from mojo_simdjson.include.internal.tape_type import TapeType
from sys import sizeof
from memory import memcpy


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
        #return iter_.walk_document(builder)
        return 0
    
    fn visit_root_primitive(inout self, inout json_iterator: JsonIterator, value: UnsafePointer[UInt8]) -> errors.ErrorType:
        return json_iterator.visit_root_primitive(self, value)

    fn visit_primitive(inout self, inout json_iterator: JsonIterator, value: UnsafePointer[UInt8]) -> errors.ErrorType:
        return json_iterator.visit_primitive(self, value)

    """
simdjson_warn_unused simdjson_inline error_code tape_builder::visit_empty_object(json_iterator &iter) noexcept {
  return empty_container(iter, internal::tape_type::START_OBJECT, internal::tape_type::END_OBJECT);
}
simdjson_warn_unused simdjson_inline error_code tape_builder::visit_empty_array(json_iterator &iter) noexcept {
  return empty_container(iter, internal::tape_type::START_ARRAY, internal::tape_type::END_ARRAY);
}

simdjson_warn_unused simdjson_inline error_code tape_builder::visit_document_start(json_iterator &iter) noexcept {
  start_container(iter);
  return SUCCESS;
}
simdjson_warn_unused simdjson_inline error_code tape_builder::visit_object_start(json_iterator &iter) noexcept {
  start_container(iter);
  return SUCCESS;
}
simdjson_warn_unused simdjson_inline error_code tape_builder::visit_array_start(json_iterator &iter) noexcept {
  start_container(iter);
  return SUCCESS;
}

simdjson_warn_unused simdjson_inline error_code tape_builder::visit_object_end(json_iterator &iter) noexcept {
  return end_container(iter, internal::tape_type::START_OBJECT, internal::tape_type::END_OBJECT);
}
simdjson_warn_unused simdjson_inline error_code tape_builder::visit_array_end(json_iterator &iter) noexcept {
  return end_container(iter, internal::tape_type::START_ARRAY, internal::tape_type::END_ARRAY);
}
simdjson_warn_unused simdjson_inline error_code tape_builder::visit_document_end(json_iterator &iter) noexcept {
  constexpr uint32_t start_tape_index = 0;
  tape.append(start_tape_index, internal::tape_type::ROOT);
  tape_writer::write(iter.dom_parser.doc->tape[start_tape_index], next_tape_index(iter), internal::tape_type::ROOT);
  return SUCCESS;
}
simdjson_warn_unused simdjson_inline error_code tape_builder::visit_key(json_iterator &iter, const uint8_t *key) noexcept {
  return visit_string(iter, key, true);
}

simdjson_warn_unused simdjson_inline error_code tape_builder::increment_count(json_iterator &iter) noexcept {
  iter.dom_parser.open_containers[iter.depth].count++; // we have a key value pair in the object at parser.dom_parser.depth - 1
  return SUCCESS;
}

simdjson_inline tape_builder::tape_builder(dom::document &doc) noexcept : tape{doc.tape.get()}, current_string_buf_loc{doc.string_buf.get()} {}

simdjson_warn_unused simdjson_inline error_code tape_builder::visit_string(json_iterator &iter, const uint8_t *value, bool key) noexcept {
  iter.log_value(key ? "key" : "string");
  uint8_t *dst = on_start_string(iter);
  dst = stringparsing::parse_string(value+1, dst, false); // We do not allow replacement when the escape characters are invalid.
  if (dst == nullptr) {
    iter.log_error("Invalid escape in string");
    return STRING_ERROR;
  }
  on_end_string(dst);
  return SUCCESS;
}

simdjson_warn_unused simdjson_inline error_code tape_builder::visit_root_string(json_iterator &iter, const uint8_t *value) noexcept {
  return visit_string(iter, value);
}

simdjson_warn_unused simdjson_inline error_code tape_builder::visit_number(json_iterator &iter, const uint8_t *value) noexcept {
  iter.log_value("number");
  return numberparsing::parse_number(value, tape);
}

simdjson_warn_unused simdjson_inline error_code tape_builder::visit_root_number(json_iterator &iter, const uint8_t *value) noexcept {
  //
  // We need to make a copy to make sure that the string is space terminated.
  // This is not about padding the input, which should already padded up
  // to len + SIMDJSON_PADDING. However, we have no control at this stage
  // on how the padding was done. What if the input string was padded with nulls?
  // It is quite common for an input string to have an extra null character (C string).
  // We do not want to allow 9\0 (where \0 is the null character) inside a JSON
  // document, but the string "9\0" by itself is fine. So we make a copy and
  // pad the input with spaces when we know that there is just one input element.
  // This copy is relatively expensive, but it will almost never be called in
  // practice unless you are in the strange scenario where you have many JSON
  // documents made of single atoms.
  //
  std::unique_ptr<uint8_t[]>copy(new (std::nothrow) uint8_t[iter.remaining_len() + SIMDJSON_PADDING]);
  if (copy.get() == nullptr) { return MEMALLOC; }
  std::memcpy(copy.get(), value, iter.remaining_len());
  std::memset(copy.get() + iter.remaining_len(), ' ', SIMDJSON_PADDING);
  error_code error = visit_number(iter, copy.get());
  return error;
}

    """
    fn visit_empty_object(inout self, json_iterator: JsonIterator) -> errors.ErrorType:
        return self.empty_container(json_iterator, tape_type.START_OBJECT, tape_type.END_OBJECT)
    
    fn visit_empty_array(inout self, json_iterator: JsonIterator) -> errors.ErrorType:
        return self.empty_container(json_iterator, tape_type.START_ARRAY, tape_type.END_ARRAY)
    
    fn visit_document_start(inout self, json_iterator: JsonIterator) -> errors.ErrorType:
        self.start_container(json_iterator)
        return errors.SUCCESS
    
    fn visit_object_start(inout self, json_iterator: JsonIterator) -> errors.ErrorType:
        self.start_container(json_iterator)
        return errors.SUCCESS
    
    fn visit_array_start(inout self, json_iterator: JsonIterator) -> errors.ErrorType:
        self.start_container(json_iterator)
        return errors.SUCCESS
    
    fn visit_object_end(inout self, json_iterator: JsonIterator) -> errors.ErrorType:
        return self.end_container(json_iterator, tape_type.START_OBJECT, tape_type.END_OBJECT)
    
    fn visit_array_end(inout self, json_iterator: JsonIterator) -> errors.ErrorType:
        return self.end_container(json_iterator, tape_type.START_ARRAY, tape_type.END_ARRAY)
    
    fn visit_document_end(inout self, json_iterator: JsonIterator) -> errors.ErrorType:
        start_tape_index = UInt32(0)
        self.tape.append(start_tape_index.cast[DType.uint64](), tape_type.ROOT)
        TapeWriter.write(
            json_iterator.dom_parser[].document.tape.unsafe_ptr() + start_tape_index,
            self.next_tape_index(json_iterator).cast[DType.uint64](),
            tape_type.ROOT
        )
        return errors.SUCCESS

    fn visit_key(inout self, json_iterator: JsonIterator, key: UnsafePointer[UInt8]) -> errors.ErrorType:
        return self.visit_string(json_iterator, key)
    
    fn increment_count(inout self, json_iterator: JsonIterator) -> errors.ErrorType:
        json_iterator.dom_parser[].open_containers[int(json_iterator.depth)].count += 1
        return errors.SUCCESS
    
    fn visit_string(inout self, json_iterator: JsonIterator, value: UnsafePointer[UInt8]) -> errors.ErrorType:
        dst = self.on_string_start(json_iterator)
        dst = stringparsing.parse_string(value + 1, dst, False)
        if not(dst):
            return errors.STRING_ERROR
        self.onstring_end(dst)
        return errors.SUCCESS

    fn visit_root_string(inout self, json_iterator: JsonIterator, value: UnsafePointer[UInt8]) -> errors.ErrorType:
        return self.visit_string(json_iterator, value)

    fn visit_true_atom(inout self, json_iterator: JsonIterator, value: UnsafePointer[UInt8]) -> errors.ErrorType:
        if atom_parsing.is_valid_true_atom(value):
            return errors.T_ATOM_ERROR
        self.tape.append(0, tape_type.TRUE_VALUE)
        return errors.SUCCESS

    fn visit_root_true_atom(inout self, json_iterator: JsonIterator, value: UnsafePointer[UInt8]) -> errors.ErrorType:
        if atom_parsing.is_valid_true_atom(value, json_iterator.remaining_len()):
            return errors.T_ATOM_ERROR
        self.tape.append(0, tape_type.TRUE_VALUE)
        return errors.SUCCESS
    
    fn visit_false_atom(inout self, json_iterator: JsonIterator, value: UnsafePointer[UInt8]) -> errors.ErrorType:
        if atom_parsing.is_valid_false_atom(value):
            return errors.F_ATOM_ERROR
        self.tape.append(0, tape_type.FALSE_VALUE)
        return errors.SUCCESS
    
    fn visit_root_false_atom(inout self, json_iterator: JsonIterator, value: UnsafePointer[UInt8]) -> errors.ErrorType:
        if atom_parsing.is_valid_false_atom(value, json_iterator.remaining_len()):
            return errors.F_ATOM_ERROR
        self.tape.append(0, tape_type.FALSE_VALUE)
        return errors.SUCCESS
    
    fn visit_null_atom(inout self, json_iterator: JsonIterator, value: UnsafePointer[UInt8]) -> errors.ErrorType:
        if atom_parsing.is_valid_null_atom(value):
            return errors.N_ATOM_ERROR
        self.tape.append(0, tape_type.NULL_VALUE)
        return errors.SUCCESS

    fn visit_root_null_atom(inout self, json_iterator: JsonIterator, value: UnsafePointer[UInt8]) -> errors.ErrorType:
        if atom_parsing.is_valid_null_atom(value, json_iterator.remaining_len()):
            return errors.N_ATOM_ERROR
        self.tape.append(0, tape_type.NULL_VALUE)
        return errors.SUCCESS
    
    fn next_tape_index(self, json_iterator: JsonIterator) -> UInt32:
        a = json_iterator.dom_parser[].document.tape.unsafe_ptr()
        return int(self.tape.next_tape_loc) - int(a)

    fn empty_container(inout self, json_iterator: JsonIterator, start: TapeType, end: TapeType) -> errors.ErrorType:
        start_index = self.next_tape_index(json_iterator).cast[DType.uint64]()
        self.tape.append(start_index + 2, start)
        self.tape.append(start_index, end)
        return errors.SUCCESS

    
    fn start_container(inout self, json_iterator: JsonIterator):
        json_iterator.dom_parser[].open_containers[int(json_iterator.depth)].tape_index = self.next_tape_index(json_iterator)
        json_iterator.dom_parser[].open_containers[int(json_iterator.depth)].count = 0
        self.tape.skip() # We don't actually *write* the start element until the end.

    fn end_container(inout self, json_iterator: JsonIterator, start: TapeType, end: TapeType) -> errors.ErrorType:
        # Write the ending tape element, pointing at the start location
        start_tape_index = json_iterator.dom_parser[].open_containers[int(json_iterator.depth)].tape_index
        # Write the start tape element, pointing at the end location (and including count)
        # Note that we differ here from the C++ version, if it exeeds 24 bits we throw an error.
        # The C++ version will just saturate in this case.
        count = json_iterator.dom_parser[].open_containers[int(json_iterator.depth)].count
        if count > 0xFFFFFF:
            return errors.CAPACITY # TODO: Add a custom error
        TapeWriter.write(
            json_iterator.dom_parser[].document.tape.unsafe_ptr() + int(start_tape_index),
            self.next_tape_index(json_iterator).cast[DType.uint64]() | count.cast[DType.uint64]() << 32, 
            start)
        return errors.SUCCESS
    

    fn on_string_start(inout self, json_iterator: JsonIterator) -> UnsafePointer[UInt8]:
        self.tape.append(
            int(self.current_string_buffer_loc) - int(json_iterator.dom_parser[].document.string_buf.unsafe_ptr()), 
            tape_type.STRING
        )
        return self.current_string_buffer_loc + sizeof[UInt32]()
    
    fn onstring_end(inout self, dst: UnsafePointer[UInt8]):
        # Should we do -1 to account for null termination? I don't think so.
        str_length = UInt32(int(dst) - int(self.current_string_buffer_loc + sizeof[UInt32]()))

        memcpy(
            dest=self.current_string_buffer_loc,
            src=UnsafePointer.address_of(str_length).bitcast[UInt8](),
            count=sizeof[UInt32](),
        )
        # Warning: here we differ from the C++ version, we don't add null termination.
        # This is because we'll be working with StringSlice, which doesn't
        # have null termination in Mojo.

        # Uncomment this if one day we need null termination
        # dst[] = 0
        self.current_string_buffer_loc = dst # + 1
