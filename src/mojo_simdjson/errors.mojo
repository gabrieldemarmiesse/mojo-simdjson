# error codes
alias SUCCESS = 0  # No error
alias CAPACITY = 1  # This parser can't support a document that big
alias MEMALLOC = 2  # Error allocating memory, most likely out of memory
alias TAPE_ERROR = 3  # Something went wrong, this is a generic error
alias DEPTH_ERROR = 4  # Your document exceeds the user-specified depth limitation
alias STRING_ERROR = 5  # Problem while parsing a string
alias T_ATOM_ERROR = 6  # Problem while parsing an atom starting with the letter 't'
alias F_ATOM_ERROR = 7  # Problem while parsing an atom starting with the letter 'f'
alias N_ATOM_ERROR = 8  # Problem while parsing an atom starting with the letter 'n'
alias NUMBER_ERROR = 9  # Problem while parsing a number
alias BIGINT_ERROR = 10  # The integer value exceeds 64 bits
alias UTF8_ERROR = 11  # the input is not valid UTF-8
alias UNINITIALIZED = 12  # unknown error, or uninitialized document
alias EMPTY = 13  # no structural element found
alias UNESCAPED_CHARS = 14  # found unescaped characters in a string.
alias UNCLOSED_STRING = 15  # missing quote at the end
alias UNSUPPORTED_ARCHITECTURE = 16  # unsupported architecture
alias INCORRECT_TYPE = 17  # JSON element has a different type than user expected
alias NUMBER_OUT_OF_RANGE = 18  # JSON number does not fit in 64 bits
alias INDEX_OUT_OF_BOUNDS = 19  # JSON array index too large
alias NO_SUCH_FIELD = 20  # JSON field not found in object
alias IO_ERROR = 21  # Error reading a file
alias INVALID_JSON_POINTER = 22  # Invalid JSON pointer syntax
alias INVALID_URI_FRAGMENT = 23  # Invalid URI fragment
alias UNEXPECTED_ERROR = 24  # indicative of a bug in simdjson
alias PARSER_IN_USE = 25  # parser is already in use.
alias OUT_OF_ORDER_ITERATION = 26  # tried to iterate an array or object out of order (checked when SIMDJSON_DEVELOPMENT_CHECKS=1)
alias INSUFFICIENT_PADDING = 27  # The JSON doesn't have enough padding for simdjson to safely parse it.
alias INCOMPLETE_ARRAY_OR_OBJECT = 28  # The document ends early.
alias SCALAR_DOCUMENT_AS_VALUE = 29  # A scalar document is treated as a value.
alias OUT_OF_BOUNDS = 30  # Attempted to access location outside of document.
alias TRAILING_CONTENT = 31  # Unexpected trailing content in the JSON input
alias NUM_ERROR_CODES = 32

alias ErrorType = Int

# TODO: use Mojo errors
