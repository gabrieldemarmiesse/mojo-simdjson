from mojo_simdjson.include.internal import tape_type
from utils import Variant
from utils import StringSlice
from collections import Optional
from memory import UnsafePointer, memcpy, Span, bitcast
import sys
from mojo_simdjson.internal.tape_ref import JSON_COUNT_MASK, JSON_VALUE_MASK
from mojo_simdjson import errors
from .. import common_defs, base


struct Document:
    var tape: List[UInt64]
    var string_buf: List[UInt8]
    var allocated_capacity: Int

    fn __init__(out self):
        self.tape = List[UInt64]()
        self.string_buf = List[UInt8]()
        self.allocated_capacity = 0

    fn __moveinit__(out self, owned other: Self):
        self.tape = other.tape^
        self.string_buf = other.string_buf^
        self.allocated_capacity = other.allocated_capacity

    fn capacity(self) -> Int:
        return self.allocated_capacity

    """
    inline error_code document::allocate(size_t capacity) noexcept {
  if (capacity == 0) {
    string_buf.reset();
    tape.reset();
    allocated_capacity = 0;
    return SUCCESS;
  }

  // a pathological input like "[[[[..." would generate capacity tape elements, so
  // need a capacity of at least capacity + 1, but it is also possible to do
  // worse with "[7,7,7,7,6,7,7,7,6,7,7,6,[7,7,7,7,6,7,7,7,6,7,7,6,7,7,7,7,7,7,6"
  //where capacity + 1 tape elements are
  // generated, see issue https://github.com/simdjson/simdjson/issues/345
  size_t tape_capacity = SIMDJSON_ROUNDUP_N(capacity + 3, 64);
  // a document with only zero-length strings... could have capacity/3 string
  // and we would need capacity/3 * 5 bytes on the string buffer
  size_t string_capacity = SIMDJSON_ROUNDUP_N(5 * capacity / 3 + SIMDJSON_PADDING, 64);
  string_buf.reset( new (std::nothrow) uint8_t[string_capacity]);
  tape.reset(new (std::nothrow) uint64_t[tape_capacity]);
  if(!(string_buf && tape)) {
    allocated_capacity = 0;
    string_buf.reset();
    tape.reset();
    return MEMALLOC;
  }
  // Technically the allocated_capacity might be larger than capacity
  // so the next line is pessimistic.
  allocated_capacity = capacity;
  return SUCCESS;
}
    """

    fn allocate(mut self, capacity: Int) -> errors.ErrorType:
        if capacity == 0:
            self.string_buf = List[UInt8]()
            self.tape = List[UInt64]()
            self.allocated_capacity = 0
            return errors.SUCCESS

        # A pathological input like "[[[[..." would generate capacity tape elements, so
        # need a capacity of at least capacity + 1, but it is also possible to do
        # worse with "[7,7,7,7,6,7,7,7,6,7,7,6,[7,7,7,7,6,7,7,7,6,7,7,6,7,7,7,7,7,7,6"
        # here capacity + 1 tape elements are
        # generated, see issue https://github.com/simdjson/simdjson/issues/345
        tape_capacity = common_defs.simdjson_roundup_n(capacity + 3, 64)
        string_capacity = common_defs.simdjson_roundup_n(
            5 * capacity // 3 + base.SIMDJSON_PADDING, 64
        )
        self.string_buf = List[UInt8](capacity=string_capacity)
        self.tape = List[UInt64](capacity=tape_capacity)

        # Here was a malloc check, but we don't "need" it in Mojo,
        # because malloc will panic if it fails.
        self.allocated_capacity = capacity
        return errors.SUCCESS

    fn dump_raw_tape(self) -> Tuple[String, Bool]:
        output = String("")
        x = self.dump_raw_tape(output)
        return (output, x)

    fn dump_raw_tape(self, mut output: String) -> Bool:
        string_length = UInt32(0)
        tape_idx = 0
        tape_val = UInt64(self.tape[tape_idx])
        type_ = UInt8(tape_val >> 56)
        output += String(tape_idx)
        output += " : "
        output += String(type_)
        tape_idx += 1
        how_many = 0
        if type_ == tape_type.ROOT:
            how_many = Int(self.tape[tape_idx] & JSON_VALUE_MASK)
        else:
            return False
        output += "\t// pointing to "
        output += String(how_many)
        output += " (right after last node)\n"
        payload = UInt64(0)
        while tape_idx < how_many:
            output += String(tape_idx)
            output += " : "
            tape_val = UInt64(self.tape[tape_idx])
            payload = tape_val & JSON_VALUE_MASK
            type_ = UInt8(tape_val >> 56)
            # Convert to switch statement when supported
            if type_ == tape_type.STRING:
                output += 'string "'
                memcpy(
                    src=self.string_buf.unsafe_ptr() + payload,
                    dest=UnsafePointer.address_of(string_length).bitcast[
                        UInt8
                    ](),
                    count=sys.sizeof[UInt32](),
                )
                slice_start = Int(payload) + sys.sizeof[UInt32]()
                output += StringSlice(
                    unsafe_from_utf8=self.string_buf[
                        slice_start : slice_start + Int(string_length)
                    ],
                )
                output += '"\n'
            elif type_ == tape_type.INT64:
                if tape_idx + 1 >= how_many:
                    return False
                output += "integer "
                tape_idx += 1
                output += String(Int64(self.tape[tape_idx]))
                output += "\n"
            elif type_ == tape_type.UINT64:
                if tape_idx + 1 >= how_many:
                    return False
                output += "unsigned integer "
                tape_idx += 1
                output += String(self.tape[tape_idx])
                output += "\n"
            elif type_ == tape_type.DOUBLE:
                output += "float "
                if tape_idx + 1 >= how_many:
                    return False
                answer = Float64(0)
                tape_idx += 1
                memcpy(
                    src=(self.tape.unsafe_ptr() + tape_idx).bitcast[UInt8](),
                    dest=UnsafePointer.address_of(answer).bitcast[UInt8](),
                    count=sys.sizeof[Float64](),
                )
                output += String(answer)
                output += "\n"
            elif type_ == tape_type.NULL_VALUE:
                output += "null\n"
            elif type_ == tape_type.TRUE_VALUE:
                output += "true\n"
            elif type_ == tape_type.FALSE_VALUE:
                output += "false\n"
            elif type_ == tape_type.START_OBJECT:
                output += "{\t// pointing to next tape location "
                output += String(UInt32(payload))
                output += " (first node after the scope), "
                output += " saturated count "
                output += String(UInt32(payload >> 32) & JSON_COUNT_MASK)
                output += "\n"
            elif type_ == tape_type.END_OBJECT:
                output += "}\t// pointing to previous tape location "
                output += String(UInt32(payload))
                output += " (start of the scope)\n"
            elif type_ == tape_type.START_ARRAY:
                output += "[\t// pointing to next tape location "
                output += String(UInt32(payload))
                output += " (first node after the scope), "
                output += " saturated count "
                output += String(UInt32(payload >> 32) & JSON_COUNT_MASK)
                output += "\n"
            elif type_ == tape_type.END_ARRAY:
                output += "]\t// pointing to previous tape location "
                output += String(UInt32(payload))
                output += " (start of the scope)\n"
            elif type_ == tape_type.ROOT:
                return False
            else:
                return False
            tape_idx += 1
        tape_val = UInt64(self.tape[tape_idx])
        payload = tape_val & JSON_VALUE_MASK
        type_ = UInt8(tape_val >> 56)
        output += String(tape_idx)
        output += " : "
        output += String(type_)
        output += "\t// pointing to "
        output += String(payload)
        output += " (start root)\n"
        return True


struct DocumentEntryIterator[document_origin: ImmutableOrigin]:
    var pointer_to_document: Pointer[Document, document_origin]
    var current_index: Int

    fn __init__(out self, ref [document_origin]document: Document):
        self.pointer_to_document = Pointer.address_of(document)
        self.current_index = 0

    fn __has_next__(self) -> Bool:
        return self.current_index < len(self.pointer_to_document[].tape)

    fn __next__(mut self) -> DocumentEntry[document_origin]:
        # first we get the tape type
        entry_type = (
            self.pointer_to_document[].tape[self.current_index] >> 56
        ).cast[DType.uint8]()
        length_of_container = Optional[UInt32](None)
        value = Optional[Variant[Int64, Float64, StringSlice[document_origin]]](
            None
        )
        # now depending on the entry type, we have more or less work to do
        # Let's start with lenght of containers
        if (
            entry_type == tape_type.START_ARRAY
            or entry_type == tape_type.START_OBJECT
        ):
            # the count are the next 24 bits
            length_of_container = (
                (self.pointer_to_document[].tape[self.current_index] >> 32)
                & ((1 << 24) - 1)
            ).cast[DType.uint32]()
        elif entry_type == tape_type.STRING:
            # the string data is stored in the next 56 bits
            index_of_string_data = Int(
                self.pointer_to_document[]
                .tape[self.current_index]
                .cast[DType.uint32]()
                & ((1 << 56) - 1)
            )
            pointer_to_string_data = UnsafePointer.address_of(
                self.pointer_to_document[].string_buf[index_of_string_data]
            )
            # We want to avoid unaligned memory load of UInt32
            var string_size: UInt32 = 0
            memcpy(
                src=pointer_to_string_data,
                dest=UnsafePointer.address_of(string_size).bitcast[UInt8](),
                count=sys.sizeof[UInt32](),
            )
            pointer_to_string_slice_start = UnsafePointer.address_of(
                self.pointer_to_document[].string_buf[
                    index_of_string_data + sys.sizeof[UInt32]()
                ]
            )
            string_slice = StringSlice[Self.document_origin](
                ptr=pointer_to_string_slice_start, length=Int(string_size)
            )

            value = Optional[
                Variant[Int64, Float64, StringSlice[document_origin]]
            ](
                Variant[Int64, Float64, StringSlice[document_origin]](
                    string_slice
                )
            )
        elif entry_type == tape_type.UINT64:
            value_as_uint64 = self.pointer_to_document[].tape[
                self.current_index + 1
            ]
            value = Optional(
                Variant[Int64, Float64, StringSlice[document_origin]](
                    value_as_uint64
                )
            )
            self.current_index += 1
        elif entry_type == tape_type.DOUBLE:
            value_as_uint64 = self.pointer_to_document[].tape[
                self.current_index + 1
            ]
            value_as_double = bitcast[DType.float64](value_as_uint64)
            value = Optional(
                Variant[Int64, Float64, StringSlice[document_origin]](
                    value_as_double
                )
            )
            self.current_index += 1

        # by default we advance of 1, but when storing int or double, we need one more
        self.current_index += 1
        return DocumentEntry[document_origin](
            entry_type, length_of_container, value
        )


# Not sure it's the best struct to store this information
struct DocumentEntry[document_origin: ImmutableOrigin]:
    var entry_type: tape_type.TapeType
    var length_of_container: Optional[UInt32]
    var value: Optional[Variant[Int64, Float64, StringSlice[document_origin]]]

    fn __init__(
        out self,
        entry_type: tape_type.TapeType,
        length_of_container: Optional[UInt32],
        value: Variant[Int64, Float64, StringSlice[document_origin]],
    ):
        self.entry_type = entry_type
        self.length_of_container = length_of_container
        self.value = value

    fn __moveinit__(out self, owned other: Self):
        self.entry_type = other.entry_type
        self.length_of_container = other.length_of_container
        self.value = other.value^

    fn __copyinit__(out self, other: Self):
        self.entry_type = other.entry_type
        self.length_of_container = other.length_of_container
        self.value = other.value
