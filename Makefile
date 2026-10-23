# Host-side build & test (macOS/Linux).  The OPENSTEP build lives in Makefile.openstep.
# Flags approximate what gcc 2.7.2 will accept: strict C89, no // comments,
# no mixed declarations, no stdint.
CC      ?= cc
CFLAGS  = -std=c89 -pedantic -Wall -Wextra -Wdeclaration-after-statement \
          -Wno-long-long -Wno-unused-parameter -Wno-deprecated-declarations -O2 -g -Iterm -Icore
BUILD   = build

TERM_SRC = $(wildcard term/*.c)
TERM_OBJ = $(patsubst term/%.c,$(BUILD)/term_%.o,$(TERM_SRC))
CORE_SRC = $(wildcard core/*.c)
CORE_OBJ = $(patsubst core/%.c,$(BUILD)/core_%.o,$(CORE_SRC))

all: test

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/term_%.o: term/%.c $(wildcard term/*.h) | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/core_%.o: core/%.c $(wildcard core/*.h) $(wildcard term/*.h) | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/test_vt: tests/test_vt.c $(TERM_OBJ)
	$(CC) $(CFLAGS) tests/test_vt.c $(TERM_OBJ) -o $@

$(BUILD)/test_core: tests/test_core.c tests/test.h $(CORE_OBJ) $(TERM_OBJ)
	$(CC) $(CFLAGS) tests/test_core.c $(CORE_OBJ) $(TERM_OBJ) -o $@

test: $(BUILD)/test_vt $(BUILD)/test_core
	$(BUILD)/test_vt
	$(BUILD)/test_core

lint:
	sh tools/lint_openstep.sh

# Syntax-check the Objective-C against the modern SDK (never linked or run).
check-objc:
	for f in app/*.m; do \
	  echo "check $$f"; \
	  $(CC) -fsyntax-only -x objective-c -fno-objc-arc -Wall -Wno-deprecated-declarations \
	    -Werror=declaration-after-statement -Wno-unused-parameter -Iterm -Icore -Iapp $$f || exit 1; \
	done

# Runs real programs through ProcessRunner (host only).
runner-smoke:
	mkdir -p build
	for f in tests/runner_smoke.m app/ProcessRunner.m app/GameEnv.m app/GameConfig.m app/UIHelpers.m; do \
	  $(CC) -c -x objective-c -fno-objc-arc -w -g -Iterm -Icore -Iapp $$f -o build/rs_$$(basename $$f .m).o || exit 1; \
	done
	for f in core/games.c core/rcfile.c; do $(CC) -c -w -g -Icore $$f -o build/rs_c_$$(basename $$f .c).o || exit 1; done
	$(CC) build/rs_*.o -framework Foundation -framework AppKit -o build/runner_smoke
	build/runner_smoke

# The terminal's transcript and the ending store (host only).
ending-smoke:
	mkdir -p build
	for f in tests/ending_smoke.m app/TerminalView.m app/EndingStore.m app/UIHelpers.m; do \
	  $(CC) -c -x objective-c -fno-objc-arc -w -g -Iterm -Icore -Iapp $$f -o build/es_$$(basename $$f .m).o || exit 1; \
	done
	for f in term/*.c core/games.c core/colours.c; do $(CC) -c -w -g -Iterm -Icore $$f -o build/es_c_$$(basename $$f .c).o || exit 1; done
	$(CC) build/es_*.o -framework Foundation -framework AppKit -o build/ending_smoke
	build/ending_smoke

# A GameSession end to end on a real pty with a fake game (host only).
session-smoke:
	mkdir -p build
	for f in tests/session_smoke.m app/GameSession.m app/GameConfig.m app/GameEnv.m app/EndingStore.m app/TerminalView.m app/UIHelpers.m; do \
	  $(CC) -c -x objective-c -fno-objc-arc -w -g -Iterm -Icore -Iapp $$f -o build/ss_$$(basename $$f .m).o || exit 1; \
	done
	for f in term/*.c core/*.c; do $(CC) -c -w -g -Iterm -Icore $$f -o build/ss_c_$$(basename $$f .c).o || exit 1; done
	$(CC) build/ss_*.o -framework Foundation -framework AppKit -o build/session_smoke
	build/session_smoke

# The New Game menu follows which games are installed (host only; links the whole application but main.m).
menu-smoke:
	mkdir -p build
	for f in tests/menu_smoke.m $(filter-out app/main.m,$(wildcard app/*.m)); do \
	  $(CC) -c -x objective-c -fno-objc-arc -w -g -Iterm -Icore -Iapp $$f -o build/ms_$$(basename $$f .m).o || exit 1; \
	done
	for f in term/*.c core/*.c; do $(CC) -c -w -g -Iterm -Icore $$f -o build/ms_c_$$(basename $$f .c).o || exit 1; done
	$(CC) build/ms_*.o -framework Foundation -framework AppKit -o build/menu_smoke
	build/menu_smoke

# Draws whole screens of everything under the address checker (host only).
draw-smoke:
	mkdir -p build
	for f in tests/draw_smoke.m app/TerminalView.m app/GameConfig.m app/UIHelpers.m; do \
	  $(CC) -c -x objective-c -fno-objc-arc -w -g -fsanitize=address,undefined -Iterm -Icore -Iapp $$f -o build/ds_$$(basename $$f .m).o || exit 1; \
	done
	for f in term/*.c core/*.c; do $(CC) -c -w -g -fsanitize=address,undefined -Iterm -Icore $$f -o build/ds_c_$$(basename $$f .c).o || exit 1; done
	$(CC) -fsanitize=address,undefined build/ds_*.o -framework Foundation -framework AppKit -o build/draw_smoke
	build/draw_smoke

# Times a whole-screen redraw (host only, optimised, no address checker).
draw-bench:
	mkdir -p build
	for f in tests/draw_bench.m app/TerminalView.m app/GameConfig.m app/UIHelpers.m; do \
	  $(CC) -c -x objective-c -fno-objc-arc -w -O2 -Iterm -Icore -Iapp $$f -o build/db_$$(basename $$f .m).o || exit 1; \
	done
	for f in term/*.c core/*.c; do $(CC) -c -w -O2 -Iterm -Icore $$f -o build/db_c_$$(basename $$f .c).o || exit 1; done
	$(CC) build/db_*.o -framework Foundation -framework AppKit -o build/draw_bench
	build/draw_bench

clean:
	rm -rf build

.PHONY: all test lint check-objc runner-smoke ending-smoke session-smoke menu-smoke draw-smoke draw-bench clean
