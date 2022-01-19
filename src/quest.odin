package main

QuestFlag :: enum u8 {
	GotSword,
}
QuestFlags :: distinct bit_set[QuestFlag; u8]

QuestData :: struct {
	quest_flags: QuestFlags,
}

Quest_IsComplete :: proc "contextless" ( flag: QuestFlag ) -> bool {
	return flag in s_gglob.quest_data.quest_flags
}

Quest_Complete :: proc "contextless" ( flag: QuestFlag ) {
	s_gglob.quest_data.quest_flags += {flag}
}
