from ..dom.document import Document
from memory import Span
from memory import UnsafePointer
from ...generic.stage1.json_structural_indexer import JsonStructuralIndexer
@value
struct OpenContainer:
    var tape_index: UInt32
    var count: UInt32


struct DomParserImplementation:
    var open_containers: List[OpenContainer]
    var is_array: List[Bool]
    # buffer passed to stage 1
    var buf: UnsafePointer[UInt8]
    var length: Int
    var document: Document
    var n_structural_indexes: UInt32
    var structural_indexes: List[UInt32]
    var next_structural_index: UInt32

    var _capacity: Int
    var _max_depth: Int

    fn __init__(out self: Self):
        self.open_containers = List[OpenContainer]()
        self.is_array = List[Bool]()
        self.buf = UnsafePointer[UInt8]()
        self.length = 0
        self.document = Document()
        self.n_structural_indexes = 0
        self.structural_indexes = List[UInt32]()
        self.next_structural_index = 0
        self._capacity = 0
        self._max_depth = 0

    fn __moveinit__(out self, owned other: Self):
        self.open_containers = other.open_containers
        self.is_array = other.is_array
        self.buf = other.buf
        self.length = other.length
        self.document = other.document^
        self.n_structural_indexes = other.n_structural_indexes
        self.structural_indexes = other.structural_indexes
        self.next_structural_index = other.next_structural_index
        self._capacity = other._capacity
        self._max_depth = other._max_depth

    fn capacity(self) -> Int:
        return self._capacity

    fn stage1(inout self, buffer: Span[UInt8]) -> errors.ErrorType:
        self.allocate(len(buffer))
        self.buf = buffer.unsafe_ptr()
        self.length = len(buffer)
        return JsonStructuralIndexer.index[128](buffer, self)

    fn allocate(inout self, amount: Int):
        # custom
        self.structural_indexes.reserve(amount)
        self.structural_indexes.resize(amount, 0)
        self._capacity = amount