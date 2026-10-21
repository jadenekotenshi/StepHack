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
	for f in tests/runner_smoke.m app/ProcessRunner.m app/GameEnv.m app/UIHelpers.m; do \
	  $(CC) -c -x objective-c -fno-objc-arc -w -g -Iterm -Icore -Iapp $$f -o build/rs_$$(basename $$f .m).o || exit 1; \
	done
	$(CC) -c -w -g -Icore core/games.c -o build/rs_games.o
	$(CC) build/rs_*.o -framework Foundation -framework AppKit -o build/runner_smoke
	build/runner_smoke

# The terminal's transcript and the ending store (host only).
ending-smoke:
	mkdir -p build
	for f in tests/ending_smoke.m app/TerminalView.m app/EndingStore.m app/UIHelpers.m; do \
	  $(CC) -c -x objective-c -fno-objc-arc -w -g -Iterm -Icore -Iapp $$f -o build/es_$$(basename $$f .m).o || exit 1; \
	done
	for f in term/*.c core/games.c; do $(CC) -c -w -g -Iterm -Icore $$f -o build/es_c_$$(basename $$f .c).o || exit 1; done
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

clean:
	rm -rf build

.PHONY: all test lint check-objc runner-smoke ending-smoke session-smoke clean
