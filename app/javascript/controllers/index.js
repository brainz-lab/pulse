// This file just imports application.js which registers all controllers
import { application } from "controllers/application"

import AssistantChatController from "controllers/assistant_chat_controller"
application.register("assistant-chat", AssistantChatController)

export { application }
