from sys.param_env import env_get_bool

alias TRACING_ENABLED = env_get_bool["SIMDJSON_TRACING_ENABLED", False]()
alias SIMDJSON_SKIP_BACKSLASH_SHORT_CIRCUIT = True
alias SIMDJSON_PADDING = 32
