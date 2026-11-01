package owui_bridge

import "core:mem"
import "core:fmt"
import "core:log"

import http "deps:odin-http"

TWELVE_KB :: mem.Kilobyte * 12

next_handler :: proc(handler: ^http.Handler, req: ^http.Request, res: ^http.Response) {
	next, ok := handler.next.?
	if !ok {
		log.error("failed to call next on middleware")
		http.respond(res, http.Status.Internal_Server_Error)
		return
	}

	next.handle(next, req, res)
	free_all(context.temp_allocator)
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

register_post_handler :: proc(router: ^http.Router, namespace: string, endpoint: string, handler: http.Handle_Proc) {
	route := build_namespace_route(namespace, endpoint)
	log.info(fmt.tprintf("registering route: %s", route))

	middleware_handler := use_middleware_handlers(handler)
	http.route_post(router, route, middleware_handler)
}

register_handlers :: proc(router: ^http.Router) {
	register_waha_handlers(router)
}

index_handler :: proc(req: ^http.Request, res: ^http.Response) {
	http.respond_plain(res, "there's nothing here")
}
