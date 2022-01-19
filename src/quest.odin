package main

QuestFlag :: enum u8 {
	GotSword,
	KilledBat1,
	KilledBat2,
	KilledBat3,
}
QuestFlags :: distinct bit_set[QuestFlag; u8]

QuestData :: struct {
	quest_flags: QuestFlags,
}

Quest_IsComplete :: proc "contextless" ( flag: QuestFlag ) -> bool {
	return flag in s_gglob.quest_data.quest_flags
}

Quest_AreComplete :: proc "contextless" ( flags: QuestFlags ) -> bool {
	return (flags & s_gglob.quest_data.quest_flags) != nil
}

Quest_Complete :: proc "contextless" ( flag: QuestFlag ) {
	s_gglob.quest_data.quest_flags += {flag}
}
