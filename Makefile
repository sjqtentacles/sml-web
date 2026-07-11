# sml-web build
MLTON      ?= mlton
BIN        := bin
TEST_MLB   := test/sources.mlb
EX_MLB     := examples/sources.mlb
SRCS       := $(shell find lib -name '*.sml' -o -name '*.sig' -o -name '*.mlb') \
              $(wildcard test/*.sml) $(TEST_MLB)

.PHONY: all test poly test-poly verify-identical all-tests example example-poly clean

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

all-tests: test test-poly verify-identical

example: $(BIN)/demo
	$(BIN)/demo

$(BIN)/demo: $(SRCS) examples/demo.sml $(EX_MLB) | $(BIN)
	$(MLTON) -output $@ $(EX_MLB)

$(BIN):
	mkdir -p $(BIN)

clean:
	rm -rf $(BIN)

# The dual-compiler contract: both suites must print byte-identical output.
# Recursive make -s captures the raw suite stdout regardless of poly strategy.
verify-identical:
	$(MAKE) -s test > $(BIN)/out-mlton.txt
	$(MAKE) -s test-poly > $(BIN)/out-poly.txt
	diff $(BIN)/out-mlton.txt $(BIN)/out-poly.txt
	@echo "byte-identical: OK"

# Demos are top-level scripts; the Poly side runs them via use-loading.
example-poly:
	sh tools/polybuild -r $(EX_MLB)
