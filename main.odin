package owui_bridge

import "core:strconv"
import "core:mem"
import "core:net"
import "core:log"
import "core:fmt"

import http "deps:odin-http"

env: Env

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintfln("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			} else {
				fmt.eprintfln("=== all allocations freed! ===\n")
			}

			mem.tracking_allocator_destroy(&track)
		}
	}

	context.logger = log.create_console_logger(.Info)
	defer log.destroy_console_logger(context.logger)

	LISTEN_PORT := get_env("PORT")
	defer delete(LISTEN_PORT)
	listen_port, ok := strconv.parse_int(LISTEN_PORT)

	if !ok {
		log.error("failed to parse port")	
		return
	}

	AUTH_SECRET := get_env("SECRET") 
	defer delete(AUTH_SECRET)

	env = Env {
		port = listen_port,
		secret_key = AUTH_SECRET
	}

	server: http.Server
	http.server_shutdown_on_interrupt(&server)

	router: http.Router
	http.router_init(&router)
	defer http.router_destroy(&router)

	http.route_get(&router, "/", http.handler(index_handler))
	register_handlers(&router)

	routed := http.router_handler(&router)
	log.infof("Listening on http://localhost:%v", env.port)

	err := http.listen_and_serve(&server, routed, net.Endpoint { address = net.IP4_Loopback, port = env.port })
	fmt.assertf(err == nil, "server stopped with error: %v", err)
}

