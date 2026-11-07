package waha

import "core:fmt"
import "core:encoding/json"
import "core:log"
import "core:mem"

import http "deps:odin-http"

TWELVE_KB					:: mem.Kilobyte * 12

WAHA_NAMESPACE 				:: "waha"

WAHA_BASE					:: "http://localhost:3999"
WAHA_SEND_TEXT_ENDPOINT		:: "/api/sendText"

Waha_Event_Meta :: struct($P: typeid) {
	id:						string,
	event:					string,
	timestamp:				i64,
	session:				string,
	payload:				P,
}

Waha_Event_Kind :: struct {
	event:					string,
}

Waha_Event_Message_Payload :: struct {
	id:						string,
	timestamp:				i64,
	from:					string,
	from_me:				bool		`json:"fromMe"`,
	source:					string,
	to:						string,
	body:					string,
	has_media:				bool		`json:"hasMedia"`,
	ack:					i8,
}

Waha_Chat_Id :: struct {
	chat_id:				string		`json:"chatId"`,
}

Waha_Send_Text_Payload :: struct {
	using chat_id:			Waha_Chat_Id,
	text:					string,
}

Waha_Set_Presence_Body :: struct {
	using chat_id:			Waha_Chat_Id,
	presence:				string,
}

// chat_map(?) -- store user chat id pairs with timestampts to then revalidate/expire
// previous chat sessions

// build the WAHA presence endpoint using the temp allocator
build_presence_endpoint :: proc(session_id: string) -> string {
	return fmt.tprintf("/api/%s/presence", session_id)
}

send_presence :: proc() {
	// todo: tried using odin-http, not really being maintained, some weird memory leak quirks.
	// thinking of building on bindings for https://github.com/civetweb/civetweb
	// and vendor:curl for requests
}

on_message :: proc(ev: Waha_Event_Meta(Waha_Event_Message_Payload)) {
	// relevant to owui.odin
	// 0. handle in-progress completions -- what do we do when we're already working on a completion?
	// 		0.1. ignore the new query completely?
	//		0.2. queue the query that's then processed after the last one is finished and returned?
	//		0.3. interrupt the current completion and re-send completion with the new query?
	//		we can send a "stop task" request to cancel tasks in flight, and then re-send the completion request
	// 1. receive message event (done)
	// 		1.1. also send back a "typing" status showing we're working on it
	// 2. build initial user prompt for model completion from message body
	// 		2.1. handle file uploads(?)
	// 		2.2. may also have to include system prompt injections for the last ~5 messages in the chat.
	//			2.2.a. if we're creating a new chat, we'll also need to fetch some recent messages.
	//			2.2.b. we can insert the messages into the chat creation/completion call (separate user/assistant messages)
	//			2.2.c. properly handle group chat interactions (participants should be clearly identified)
	// 3. create the exchange chat through the owui api (/api/v1/chats/new)
	// 		3.1. chats should not be created for every message (conversations need to flow somewhat)
	// 			3.1.a. option a: keep track of user's last engagement and renew the timestamp each time --
	// 			if the elapsed time between last interaction and a new interaction is greater than
	// 			15 minutes, for example, create a new chat, otherwise route messages to the existing chat
	// 		3.2. owui returns the task ids and the chat id, in the following form which we can then use for subsequent calls
	// 4. call the owui completion endpoint (/api/chat/completions)
	// 5. wait for completion to finish -- owui recommend fetching /api/tasks/chat/$CHAT_ID and checking
	// if task_ids is more than 0.
	// 6. fetch the completed answer (we're definitely not streaming the output to whatsapp) /api/v1/chats/$CHAT_ID
	// 7. structure output for whatsapp response
	// 8. call waha endpoint to send message response.

	log.infof("received an epic message: %v", ev.payload.body)
}

handle_event :: proc($P: typeid, bytes: []u8, handler: proc(ev: Waha_Event_Meta(P))) {
	ev: Waha_Event_Meta(P)
	if err := json.unmarshal(bytes, &ev, allocator=context.temp_allocator); err != nil {
		log.errorf("failed to unmarshal %v event: %v", typeid_of(P), err)
		return
	}

	handler(ev)
}

event_handler :: proc(req: ^http.Request, res: ^http.Response) {
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
			handle_event(Waha_Event_Message_Payload, bytes, on_message)
		case:
			log.errorf("skipping unregocnised waha event \"%s\"", event_kind.event)
		}

		http.respond(res, http.Status.OK)
	})
}

send_message_handler :: proc(req: ^http.Request, res: ^http.Response) {
}

recent_messages_handler :: proc(req: ^http.Request, res: ^http.Response) {
}
