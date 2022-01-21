@echo off
echo build images...
set imgs=img_src\key.png ^
		 img_src\bat.png ^
		 img_src\chest.png ^
		 img_src\tileset.png ^
		 img_src\mc.png ^
		 img_src\status_bar.png ^
		 img_src\miru.png ^
		 img_src\dialog_background.png ^
		 img_src\sword_altar.png ^
		 img_src\title_screen.png ^
		 img_src\half_heart.png ^
		 img_src\ui_items_icon.png ^
		 img_src\game_over_screen.png
w4 png2src --odin %imgs% -t img_src\template.txt -o src\images.odin
echo build tilemap...
map_editor\build\map_editor.exe -input "map_editor\build\map.txt" -export "src\tilemap_export.odin"
echo build game...
C:\Home\Odin\odin build src -out:build/cart.wasm -target:freestanding_wasm32 -disable-assert -no-crt -no-entry-point -o:size -extra-linker-flags:"--import-memory -zstack-size=8192 --initial-memory=65536 --max-memory=65536 --global-base=6560 --lto-O3 --gc-sections --strip-all"
wasm-opt build/cart.wasm -o build/cart-opt.wasm -Oz --strip-dwarf --strip-producers --zero-filled-memory
echo done
forfiles /p build /m cart.wasm /c "cmd /c echo size: @fsize bytes"
forfiles /p build /m cart-opt.wasm /c "cmd /c echo size opt: @fsize bytes"