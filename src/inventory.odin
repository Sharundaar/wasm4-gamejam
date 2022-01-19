package main

import "w4"

INVENTORY_ITEM_SPACING :: 2
INVENTORY_ITEM_SIZE :: 8

InventoryItem :: enum {
	Sword,
	Torch,
	Count,
}

InventoryOffset :: struct { x, w: u8 }
InventoryUIData :: struct {
	icons: [InventoryItem.Count]InventoryOffset, // x and w offset into the inventory data image
}
s_InventoryUIData := InventoryUIData {
	{
		{ 0, 5 },
		{ 5, 5 },
	},
}

Inventory :: struct {
	items: [InventoryItem.Count]b8, // true if item is owned
	current_item: u8,
}

SelectNextItem :: proc "contextless" ( inventory: ^Inventory ) {
	starting_point := inventory.current_item
	for {
		inventory.current_item = (inventory.current_item + 1) % u8(len(inventory.items))
		if inventory.items[inventory.current_item] || inventory.current_item == starting_point do break
	}
}

DrawInventory :: proc "contextless" ( start_x, start_y: i32, inventory: ^Inventory ) {
	x, y := start_x, start_y

	icons := GetImage( ImageKey.ui_items_icon )
	w4.DRAW_COLORS^ = 0x2341
	for has_item, idx in inventory.items {
		if has_item {
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

GiveNewItem :: proc "contextless" ( entity: ^Entity, item: InventoryItem ) {
	
}

NewItemAnimation_Update :: proc "contextless" () {
	if s_gglob.state != GameState.NewItemAnimation do return


}
