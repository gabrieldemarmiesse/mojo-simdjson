from .json_scanner import JsonScanner
from memory import Span
from ... import errors
from ...include.generic.dom_parser_implementation import DomParserImplementation
from .buf_block_reader import BufferBlockReader
from memory import UnsafePointer
from collections import InlineArray
from .json_scanner import JsonBlock
from memory.unsafe import pack_bits
import bit
from ...debug import bin_display_reverse
from utils import StringSlice


struct Utf8Checker:
    # TODO: Use the stdlib for this.
    pass

    fn __init__(out self):
        pass

    fn check_next_input(self, in_: SIMD[DType.uint8, 64]):
        pass

    fn check_eof(self):
        pass

    fn errors(self) -> errors.ErrorType:
        return errors.SUCCESS


struct BitIndexer:
    var tail: UnsafePointer[UInt32]

    fn __init__(out self, structural_indexes: Span[UInt32]):
        self.tail = structural_indexes.unsafe_ptr()

    fn write_index(mut self, idx: UInt32, mut bits: UInt64, i: Int):
        # could reverse bit here if faster on some platforms
        (self.tail + i)[] = (
            idx + bit.count_trailing_zeros(bits).cast[DType.uint32]()
        )
        bits = bits & (bits - 1)  # TODO: use blsr

    fn write(mut self, idx: UInt32, owned bits: UInt64):
        # In some instances, the next branch is expensive because it is mispredicted.
        # Unfortunately, in other cases,
        # it helps tremendously.
        if bits == 0:
            return

        count = Int(bit.pop_count(bits))

        for i in range(count):
            self.write_index(idx, bits, i)

        self.tail += count


fn print_simd_as_string(x: SIMD[DType.uint8, _]):
    a = InlineArray[UInt8, x.size](0)
    a.unsafe_ptr().store(x)
    print(StringSlice(unsafe_from_utf8=a))


struct JsonStructuralIndexer:
    var scanner: JsonScanner
    var checker: Utf8Checker
    var indexer: BitIndexer
    var prev_structurals: UInt64
    var unescaped_chars_error: UInt64

    fn __init__(out self, structural_indexes: Span[UInt32]):
        self.scanner = JsonScanner()
        self.checker = Utf8Checker()
        self.indexer = BitIndexer(structural_indexes)
        self.prev_structurals = 0
        self.unescaped_chars_error = 0

    @staticmethod
    fn index[
        step_size: Int
    ](
        buffer: Span[UInt8], mut parser: DomParserImplementation
    ) -> errors.ErrorType:
        if len(buffer) > parser.capacity():
            print("buffer too big")
            return errors.CAPACITY

        if len(buffer) == 0:
            return errors.EMPTY

        reader = BufferBlockReader[step_size](buffer)
        indexer = JsonStructuralIndexer(parser.structural_indexes)

        while reader.has_full_block():
            full_block = reader.full_block()
            indexer.step[step_size](full_block.unsafe_ptr(), reader)
            _ = full_block  # live long enough

        # take care of the last partial block
        block = InlineArray[UInt8, step_size](0x20)
        number_of_chars = reader.get_remainder(block.unsafe_ptr())
        if number_of_chars == 0:
            return errors.UNEXPECTED_ERROR
        indexer.step[step_size](block.unsafe_ptr(), reader)
        return indexer.finish(parser, reader.block_index(), len(buffer))

    fn step[
        step_size: Int
    ](
        mut self,
        block: UnsafePointer[UInt8],
        mut reader: BufferBlockReader[step_size],
    ):
        #@parameter
        for start in range(0, step_size, 64):
            in_ = (block + start).load[width=64]()
            print("-" * 64)
            print_simd_as_string(in_)
            json_block = self.scanner.next(in_)
            self.next(in_, json_block, reader.block_index() + start)
        reader.advance()

    fn next(
        mut self,
        in_: SIMD[DType.uint8, 64],
        json_block: JsonBlock,
        index: Int,
    ):
        unescaped = pack_bits(in_ <= 0x1F)

        self.checker.check_next_input(in_)
        self.indexer.write(UInt32(index - 64), self.prev_structurals)

        self.prev_structurals = json_block.structural_start()
        bin_display_reverse(
            self.prev_structurals, "structural_start"
        )
        self.unescaped_chars_error |= json_block.non_quote_inside_string(
            unescaped
        )

    fn finish(
        mut self, mut parser: DomParserImplementation, idx: Int, length: Int
    ) -> errors.ErrorType:
        self.indexer.write(UInt32(idx - 64), self.prev_structurals)
        error = self.scanner.finish()

        # Is more complicated in the original implementation
        if error != errors.SUCCESS:
            return error

        if self.unescaped_chars_error:
            return errors.UNESCAPED_CHARS

        pointer_to_start = UnsafePointer.address_of(
            parser.structural_indexes[0]
        )
        parser.n_structural_indexes = (
            Int(self.indexer.tail) - Int(pointer_to_start)
        ) // 4
        print("n_structural_indexes, in func", parser.n_structural_indexes)

        parser.structural_indexes[Int(parser.n_structural_indexes)] = UInt32(
            length
        )  # used later in partial == stage1_mode::streaming_final
        parser.structural_indexes[
            Int(parser.n_structural_indexes + 1)
        ] = UInt32(length)
        parser.structural_indexes[Int(parser.n_structural_indexes + 2)] = 0
        parser.next_structural_index = 0

        if parser.n_structural_indexes == 0:
            return errors.EMPTY

        if (
            parser.structural_indexes[Int(parser.n_structural_indexes - 1)]
            > length
        ):
            return errors.UNEXPECTED_ERROR

        self.checker.check_eof()
        return self.checker.errors()
