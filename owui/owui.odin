package owui

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

Owui_Chat_Message :: struct {
	role:					string,
	content:				string,
}

Owui_Chat_Create_Body :: struct {
	chat:					struct {
		title:					string,
		models:					[]string,
		history:				struct {
			current
		}
	}
}

Owui_Chat_Completion_Body :: struct {
	id:						string
	model:					string,
	messages:				[]Owui_Chat_Message,
	stream:					bool,
	chat_id:				string,
	features:				struct {
		web_search:				bool,
		code_interpreter:		bool,
		image_generation:		bool,
		memory:					bool,
	},
	tool_ids:				[]string,
	terminal_id:			string,
	background_tasks:		struct {
		title_generation:		bool,
		tags_generation:		bool,
		follow_up_generation:	bool,
	}
}

Owui_Chat_Completion_Response :: struct {
	status:					bool,
	task_ids:				[]string,
	chat_id:				string,
}

// distinguish async/sync?
create_chat :: proc(title: string, model: string) {
}

chat_completion :: proc(chat_id: string) {}

// /api/v1/chats/$CHAT_ID
get_chat_messages :: proc(chat_id: string) {}

// /api/tasks/chat/$CHAT_ID
get_chat_tasks :: proc() {}

stop_task :: proc(task_id: string) {}

