@echo off
echo build images...
set imgs=img_src\key.png ^
		 img_src\dude.png ^
		 img_src\bat.png ^
		 img_src\chest.png ^
		 img_src\tileset.png ^
		 img_src\fire.png ^
		 img_src\mc.png ^
		 img_src\status_bar.png ^
		 img_src\miru.png ^
		 img_src\dialog_background.png ^
		 img_src\sword_altar.png ^
		 img_src\title_screen.png ^
		 img_src\half_heart.png
w4 png2src --odin %imgs% -t img_src\template.txt -o src\images.odin
echo build game...
C:\Home\Odin\odin build src -out:build/cart.wasm -target:freestanding_wasm32 -no-entry-point -o:size -extra-linker-flags:"--import-memory -zstack-size=8192 --initial-memory=65536 --max-memory=65536 --global-base=6560 --lto-O3 --gc-sections --strip-all"
echo done