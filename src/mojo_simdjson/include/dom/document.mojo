from mojo_simdjson.include.internal import tape_type
from utils import Variant
from utils import StringSlice
from collections import Optional
from memory import UnsafePointer, memcpy, Span, bitcast
import sys

struct Document:
    var tape: List[UInt64]
    var string_buf: List[UInt8]

    fn __init__(out self):
        self.tape = List[UInt64]()
        self.string_buf = List[UInt8]()

    fn __moveinit__(out self, owned other: Self):
        self.tape = other.tape^
        self.string_buf = other.string_buf^



struct DocumentEntryIterator[document_origin: ImmutableOrigin]:
    var pointer_to_document: Pointer[Document, document_origin]
    var current_index: Int

    fn __init__(out self, ref [document_origin] document: Document):
        self.pointer_to_document = Pointer.address_of(document)
        self.current_index = 0
    
    fn __has_next__(self) -> Bool:
        return self.current_index < len(self.pointer_to_document[].tape)

    fn __next__(mut self) -> DocumentEntry[document_origin]:
        # first we get the tape type
        entry_type = (self.pointer_to_document[].tape[self.current_index] >> 56).cast[DType.uint8]()
        length_of_container = Optional[UInt32](None)
        value = Optional[Variant[Int64, Float64, StringSlice[document_origin]]](None)
        # now depending on the entry type, we have more or less work to do
        # Let's start with lenght of containers
        if entry_type == tape_type.START_ARRAY or entry_type == tape_type.START_OBJECT:
            # the count are the next 24 bits
            length_of_container = ((self.pointer_to_document[].tape[self.current_index] >> 32) & ((1 << 24) - 1)).cast[DType.uint32]()
        elif entry_type == tape_type.STRING:
            # the string data is stored in the next 56 bits
            index_of_string_data = int(self.pointer_to_document[].tape[self.current_index].cast[DType.uint32]() & ((1 << 56) - 1))
            pointer_to_string_data = UnsafePointer.address_of(self.pointer_to_document[].string_buf[index_of_string_data])
            # We want to avoid unaligned memory load of UInt32
            var string_size: UInt32 = 0
            memcpy(
                src=pointer_to_string_data, 
                dest=UnsafePointer.address_of(string_size).bitcast[UInt8](),
                count=sys.sizeof[UInt32](),
            )
            pointer_to_string_slice_start = UnsafePointer.address_of(
                self.pointer_to_document[].string_buf[index_of_string_data + sys.sizeof[UInt32]()]
            )
            string_slice = StringSlice[Self.document_origin](ptr=pointer_to_string_slice_start, length=int(string_size))
            
            value = Optional[Variant[Int64, Float64, StringSlice[document_origin]]](Variant[Int64, Float64, StringSlice[document_origin]](string_slice))
        elif entry_type == tape_type.UINT64:
            value_as_uint64 = self.pointer_to_document[].tape[self.current_index + 1]
            value = Optional(Variant[Int64, Float64, StringSlice[document_origin]](value_as_uint64))
            self.current_index += 1
        elif entry_type == tape_type.DOUBLE:
            value_as_uint64 = self.pointer_to_document[].tape[self.current_index + 1]
            value_as_double = bitcast[DType.float64](value_as_uint64)
            value = Optional(Variant[Int64, Float64, StringSlice[document_origin]](value_as_double))
            self.current_index += 1

        # by default we advance of 1, but when storing int or double, we need one more
        self.current_index += 1
        return DocumentEntry[document_origin](entry_type, length_of_container, value)



            

# Not sure it's the best struct to store this information
struct DocumentEntry[document_origin: ImmutableOrigin]:
    var entry_type: tape_type.TapeType
    var length_of_container: Optional[UInt32]
    var value: Optional[Variant[Int64, Float64, StringSlice[document_origin]]]

    fn __init__(out self, entry_type: tape_type.TapeType, length_of_container: Optional[UInt32],  value: Variant[Int64, Float64, StringSlice[document_origin]]):
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