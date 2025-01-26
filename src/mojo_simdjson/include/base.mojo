# The maximum document size supported by simdjson.
alias SIMDJSON_MAXSIZE_BYTES = 0xFFFFFFFF

# The amount of padding needed in a buffer to parse JSON.
#
# The input buf should be readable up to buf + SIMDJSON_PADDING
# this is a stopgap; there should be a better description of the
# main loop and its behavior that abstracts over this
# See https://github.com/simdjson/simdjson/issues/174
alias SIMDJSON_PADDING = 64


# By default, simdjson supports this many nested objects and arrays.
#
# This is the default for parser::max_depth().
alias DEFAULT_MAX_DEPTH = 1024
