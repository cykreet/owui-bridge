package owui_bridge

import "core:encoding/json"
import "core:log"
import "core:fmt"

import http "deps:odin-http"

WAHA_NAMESPACE 			:: "waha"

WAHA_BASE				:: "http://localhost:3999"
WAHA_SEND_TEXT_ENDPOINT :: "/api/sendText"

Waha_Event_Meta :: struct($P: typeid) {
	id:				string,
	event:			string,
	timestamp:		i64,
	session:		string,
	payload:		P,
}

Waha_Event_Kind :: struct {
	event:			string,
}

Waha_Event_Message_Payload :: struct {
	id:				string,
	timestamp:		i64,
	from:			string,
	from_me:		bool		`json:"fromMe"`,
	source:			string,
	to:				string,
	body:			string,
	has_media:		bool		`json:"hasMedia"`,
	ack:			i8,
}

Waha_Send_Text_Payload :: struct {
	chat_id:		string		`json:"chatId"`,
	text:			string,
}

waha_on_message :: proc(ev: Waha_Event_Meta(Waha_Event_Message_Payload)) {
	log.info(fmt.tprintf("received an epic message: %v", ev.payload.body))
}

waha_handle_event :: proc($P: typeid, bytes: []u8, handler: proc(ev: Waha_Event_Meta(P))) {
	ev: Waha_Event_Meta(P)
	if err := json.unmarshal(bytes, &ev, allocator=context.temp_allocator); err != nil {
		log.error(fmt.tprintf("failed to unmarshal %v event: %v", typeid_of(P), err))
		return
	}

	handler(ev)
}

waha_event_handler :: proc(req: ^http.Request, res: ^http.Response) {
	http.body(req, TWELVE_KB, res, proc(res: rawptr, body: http.Body, err: http.Body_Error) {
		res := cast(^http.Response)res

		if err != nil {
			http.respond(res, http.body_error_status(err))
			return
		}

		bytes := transmute([]u8)(body)
		event_kind: Waha_Event_Kind
		unmarshall_err := json.unmarshal(bytes, &event_kind, allocator=context.temp_allocator)
		if unmarshall_err != nil {
			log.error("failed to unmarshal event kind")
			return
		}

		switch event_kind.event {
		case "message":
			waha_handle_event(Waha_Event_Message_Payload, bytes, waha_on_message)
		case:
			log.error("skipping unregocnised waha event \"%s\"", event_kind.event)
		}

		http.respond(res, http.Status.OK)
	})
}

waha_send_message_handler :: proc(req: ^http.Request, res: ^http.Response) {
	http.body(req, TWELVE_KB, res, proc(res: rawptr, body: http.Body, err: http.Body_Error) {
		res := cast(^http.Response)res

		if err != nil {
			http.respond(res, http.body_error_status(err))
			return
		}

		bytes := transmute([]u8)(body)
		event_kind: Waha_Event_Kind
		unmarshall_err := json.unmarshal(bytes, &event_kind, allocator=context.temp_allocator)
		if unmarshall_err != nil {
			log.error("failed to unmarshal event kind")
			return
		}

		switch event_kind.event {
		case "message":
			waha_handle_event(Waha_Event_Message_Payload, bytes, waha_on_message)
		case:
			log.error("skipping unregocnised waha event \"%s\"", event_kind.event)
		}

		http.respond(res, http.Status.OK)
	})
}

register_waha_handlers :: proc(router: ^http.Router) {
	register_post_handler(router, WAHA_NAMESPACE, "event", waha_event_handler)
	register_post_handler(router, WAHA_NAMESPACE, "send-message", waha_send_message_handler)
}
