PREFIX ?= $(HOME)/.config/CommandK
APP = $(PREFIX)/CommandK.app
SWIFT = $(wildcard Sources/*.swift)

.PHONY: build install deps bootstrap

deps:
	brew install koekeishiya/formulae/yabai koekeishiya/formulae/skhd jq

bootstrap:
	@command -v brew >/dev/null 2>&1 || { echo "Homebrew is required: https://brew.sh"; exit 1; }
	brew install koekeishiya/formulae/yabai koekeishiya/formulae/skhd jq
	@echo ""
	@echo "Dependencies ready. Now:"
	@echo "  1. Grant Accessibility to skhd and yabai (System Settings > Privacy & Security > Accessibility)."
	@echo "  2. sudo yabai --install-sa && sudo yabai --load-sa   (recommended for full window control)"
	@echo "  3. brew services start skhd && brew services start yabai"
	@echo "  4. make install"

build:
	mkdir -p build/CommandK.app/Contents/MacOS
	cp Resources/Info.plist build/CommandK.app/Contents/Info.plist
	swiftc -O -o build/CommandK.app/Contents/MacOS/CommandK $(SWIFT) -framework AppKit
	codesign -fs - build/CommandK.app

install: build
	mkdir -p $(PREFIX)
	rm -rf $(APP)
	cp -R build/CommandK.app $(APP)
	cp scripts/wm $(PREFIX)/wm
	cp scripts/command-k $(PREFIX)/command-k
	chmod +x $(PREFIX)/wm $(PREFIX)/command-k
	if [ ! -f $(PREFIX)/commands.json ]; then cp Resources/commands.json $(PREFIX)/commands.json; fi
	$(APP)/Contents/MacOS/CommandK --write-skhdrc
	yabai -m rule --add app="^CommandK$$" manage=off sticky=on 2>/dev/null || true
	@echo "Installed to $(APP)"
	@echo "Press Cmd+K. Gear or type Settings to edit shortcuts."
