APP_NAME    := Cursormon
BIN_PATH    := .build/release/$(APP_NAME)
APP_BUNDLE  := build/$(APP_NAME).app
CONTENTS    := $(APP_BUNDLE)/Contents

.PHONY: all build bundle run clean rebuild

all: bundle

build:
	swift build -c release

bundle: build
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources
	@cp $(BIN_PATH) $(CONTENTS)/MacOS/$(APP_NAME)
	@cp Resources/Info.plist $(CONTENTS)/Info.plist
	@codesign --force --sign - $(APP_BUNDLE)
	@echo "[OK] $(APP_BUNDLE) built and signed (ad-hoc)"

run: bundle
	open $(APP_BUNDLE)

rebuild: clean bundle

clean:
	rm -rf .build build
