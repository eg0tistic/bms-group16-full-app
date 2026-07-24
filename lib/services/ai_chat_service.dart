// Online AI is not enabled. Route future AI calls through a Supabase Edge Function
// or backend proxy — never hardcode API keys in source code.
class AiChatService {
  static Future<String?> ask(String question) async => null;
}
