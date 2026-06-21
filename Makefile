# sml-web build
MLTON      ?= mlton
BIN        := bin
TEST_MLB   := test/sources.mlb
EX_MLB     := examples/app.mlb
SRCS       := $(shell find lib -name '*.sml' -o -name '*.sig' -o -name '*.mlb') \
              $(wildcard test/*.sml) $(TEST_MLB)

.PHONY: all test poly test-poly all-tests example clean

all: $(BIN)/test-mlton

$(BIN)/test-mlton: $(SRCS) | $(BIN)
	$(MLTON) -output $@ $(TEST_MLB)

test: $(BIN)/test-mlton
	$(BIN)/test-mlton

poly: $(BIN)/test-poly

$(BIN)/test-poly: $(SRCS) tools/polybuild | $(BIN)
	sh tools/polybuild -o $@ $(TEST_MLB)

test-poly: $(BIN)/test-poly
	$(BIN)/test-poly

all-tests: test test-poly

example: $(BIN)/app
	$(BIN)/app

$(BIN)/app: $(SRCS) examples/app.sml $(EX_MLB) | $(BIN)
	$(MLTON) -output $@ $(EX_MLB)

$(BIN):
	mkdir -p $(BIN)

clean:
	rm -rf $(BIN)
