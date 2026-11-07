package owui_bridge

WAHA_SUPPORT :: #config(WAHA_SUPPORT, false)

import "core:fmt"
import "core:log"

import waha "waha"

import http "deps:odin-http"

when ODIN_DEBUG {
	@(private = "file")
	handler_names: map[rawptr]string

	register_handler_name :: proc(p: http.Handler_Proc, name: string) {
		handler_names[rawptr(p)] = name
	}
}

next_handler :: proc(handler: ^http.Handler, req: ^http.Request, res: ^http.Response) {
	// ensure we free temp allocations regardless of early returns
	defer free_all(context.temp_allocator)

	next, ok := handler.next.?
	if !ok {
		when ODIN_DEBUG {
			handler_name := handler_names[rawptr(handler.handle)] or_else "UNKNOWN"
			log.errorf("handler \"%s\" has no next handler", handler_name)
		} else {
			log.error("failed to call next on handler middleware")
		}

		http.respond(res, http.Status.Internal_Server_Error)
		return
	}

	next.handle(next, req, res)
}

secret_middleware_handler :: proc(handler: ^http.Handler, req: ^http.Request, res: ^http.Response) {
	if http.headers_get(req.headers, "X-Secret") != env.secret_key {
		http.respond(res, http.Status.Unauthorized)
		return
	}

	next_handler(handler, req, res)
}

build_namespace_route :: proc(namespace: string, endpoint: string) -> string {
	return fmt.tprintf("/%s/%s", namespace, endpoint)
}

use_middleware_handlers :: proc(handler: http.Handle_Proc) -> http.Handler {
	// handlers are tied to the router lifetime, and since the
	// router is destroyed when the server is shutdown, not freeing these is fine
	inner := new(http.Handler, context.allocator)
	inner^ = http.handler(handler)

	return http.middleware_proc(inner, secret_middleware_handler)
}

register_post_handler :: proc(router: ^http.Router, namespace: string, endpoint: string, handler: http.Handle_Proc, handler_name := #caller_expression(handler)) {
	route := build_namespace_route(namespace, endpoint)
	log.infof("registering route: %s", route)

	middleware_handler := use_middleware_handlers(handler)
	http.route_post(router, route, middleware_handler)

	when ODIN_DEBUG {
		// stores the handler name with its rawptr so we can track it down later
		register_handler_name(middleware_handler.handle, handler_name)
	}
}

register_handlers :: proc(router: ^http.Router) {
	when WAHA_SUPPORT {
		register_post_handler(router, waha.WAHA_NAMESPACE, "event", waha.event_handler)
		register_post_handler(router, waha.WAHA_NAMESPACE, "send-message", waha.send_message_handler)
		register_post_handler(router, waha.WAHA_NAMESPACE, "recent-messages", waha.recent_messages_handler)
	}
}

index_handler :: proc(req: ^http.Request, res: ^http.Response) {
	http.respond_plain(res, "there's nothing here")
}
