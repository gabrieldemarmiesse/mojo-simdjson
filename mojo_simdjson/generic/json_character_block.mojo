from mojo_simdjson import haswell

@value
struct JsonCharacterBlock:
    var _whitespace: UInt64
    var _op: UInt64

    @staticmethod
    fn classify(in_: SIMD[DType.uint8, 64]) -> JsonCharacterBlock:
        return haswell.classify(in_)

    @always_inline
    fn whitespace(self) -> UInt64:
        return self._whitespace

    @always_inline
    fn op(self) -> UInt64:
        return self._op

    @always_inline
    fn scalar(self) -> UInt64:
        return ~(self.op() | self.whitespace())

