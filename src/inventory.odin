package main

import "w4"

INVENTORY_ITEM_SPACING :: 2
INVENTORY_ITEM_SIZE :: 8

InventoryItem :: enum {
	Sword,
	Torch,
	Count,
}

InventoryOffset :: struct { x, w: u8, mask: u16 }
InventoryUIData :: struct {
	icons: [InventoryItem.Count]InventoryOffset, // x and w offset into the inventory data image
}
s_InventoryUIData := InventoryUIData {
	{
		{ 0, 5, 0x2140 },
		{ 5, 5, 0x2143 },
	},
}

Inventory :: struct {
	items: [InventoryItem.Count]b8, // true if item is owned
	current_item: u8,
}

Inventory_SelectNextItem :: proc "contextless" ( inventory: ^Inventory ) {
	starting_point := inventory.current_item
	for {
		inventory.current_item = (inventory.current_item + 1) % u8(len(inventory.items))
		if inventory.items[inventory.current_item] || inventory.current_item == starting_point do break
	}
}

Inventory_SelectItem :: proc "contextless" ( inventory: ^Inventory, item: InventoryItem ) {
	if inventory.items[item] do inventory.current_item = u8( item )
}

DrawInventory :: proc "contextless" ( start_x, start_y: i32, inventory: ^Inventory ) {
	x, y := start_x, start_y

	icons := GetImage( ImageKey.ui_items_icon )
	for has_item, idx in inventory.items {
		if has_item {
			w4.DRAW_COLORS^ = s_InventoryUIData.icons[idx].mask
			w4.blit_sub( &icons.bytes[0], x, y, u32(s_InventoryUIData.icons[idx].w), 8, u32(s_InventoryUIData.icons[idx].x), 0, int(icons.w), icons.flags )
		}
		x += INVENTORY_ITEM_SIZE + INVENTORY_ITEM_SPACING
	}

	// print inventory selector
	if inventory.items[inventory.current_item] {
		SELECTOR_IMG_X :: 30
		SELECTOR_IMG_W :: 2
		x = start_x - 2 + i32(inventory.current_item) * (INVENTORY_ITEM_SIZE + INVENTORY_ITEM_SPACING)
		w4.blit_sub( &icons.bytes[0], x, y, SELECTOR_IMG_W, 8, SELECTOR_IMG_X, 0, int(icons.w), icons.flags )
		x += INVENTORY_ITEM_SIZE
		w4.blit_sub( &icons.bytes[0], x, y, SELECTOR_IMG_W, 8, SELECTOR_IMG_X, 0, int(icons.w), icons.flags + {.FLIPX} )
	}
}

Inventory_GiveNewItem :: proc "contextless" ( entity: ^Entity, item: InventoryItem ) {
	s_gglob.game_state = GameState.NewItemAnimation
	s_gglob.new_item = item
	s_gglob.new_item_animation_counter = 0
	s_gglob.new_item_entity_target = entity
}

Inventory_GiveNewItem_Immediate :: proc "contextless" ( entity: ^Entity, item: InventoryItem ) {
	entity.inventory.items[item] = true
}

Inventory_HasItem :: proc "contextless" ( entity: ^Entity, item: InventoryItem ) -> bool {
	return bool( entity.inventory.items[item] )
}

Inventory_HasItemSelected :: proc "contextless" ( entity: ^Entity, item: InventoryItem ) -> bool {
	return bool( entity.inventory.items[item] ) && entity.inventory.current_item == u8( item )
}

NewItemMusic := Sound {
	{
		{ 500, 500, 0, {sustain=20}, .Pulse1, 25 },
		{ 300, 300, 15, {sustain=20}, .Pulse2, 25 },
		{ 500, 500, 25, {sustain=20}, .Pulse1, 25 },
		{ 700, 700, 40, {sustain=20}, .Pulse1, 25 },
		// { 800, 100, 27, {sustain=30}, .Pulse2, 25 },
		/*
		{ 400, 400, 0, {sustain=10}, .Pulse1, 25 },
		{ 800, 800, 11, {sustain=10}, .Pulse1, 25 },
		{ 1000, 1000, 22, {sustain=10}, .Pulse1, 25 },
		{ 3000, 3000, 33, {sustain=10}, .Pulse2, 25 },
		*/
		// { 2500, 3000, 33, {sustain=10}, .Pulse2, 25 },
		// { 600, 600, 0, {sustain=40}, .Pulse2, 25 },
		// { 1000, 1000, 41, {sustain=40}, .Pulse2, 25 },
	},
}

NewItemAnimation_Update :: proc "contextless" () {
	if s_gglob.game_state != GameState.NewItemAnimation do return

	ANIMATION_DURATION :: 90

	if s_gglob.new_item_animation_counter == 0 {
		Sound_Play( &NewItemMusic )
	}

	x := s_gglob.new_item_entity_target.position.offsets.x + ( 8 - i32(s_InventoryUIData.icons[s_gglob.new_item].w ) ) / 2
	y := s_gglob.new_item_entity_target.position.offsets.y - 8 - 6

	t := f32(s_gglob.new_item_animation_counter) / ANIMATION_DURATION
	y += auto_cast ( t * 4 )

	icons := GetImage( ImageKey.ui_items_icon )
	w4.DRAW_COLORS^ = s_InventoryUIData.icons[s_gglob.new_item].mask
	w4.blit_sub( &icons.bytes[0], x, y, u32(s_InventoryUIData.icons[s_gglob.new_item].w), 8, u32(s_InventoryUIData.icons[s_gglob.new_item].x), 0, int(icons.w), icons.flags )

	if s_gglob.new_item_animation_counter > ANIMATION_DURATION {
		s_gglob.game_state = GameState.Game
		Inventory_GiveNewItem_Immediate( s_gglob.new_item_entity_target, s_gglob.new_item )
		Inventory_SelectItem( &s_gglob.new_item_entity_target.inventory, s_gglob.new_item )
	}

	s_gglob.new_item_animation_counter += 1
}
