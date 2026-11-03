package owui_bridge

import "core:os"
import "core:log"

Env :: struct {
	port: int,
	secret_key: string,
}

get_env :: proc(name: string) -> string {
	value, ok := os.lookup_env(name, context.allocator)
	if !ok {
		log.errorf("environment variable not provided: %s", name)
		os.exit(1)
	}

	return value
}
