
# ==========================================
# NoC Router Verification
# ==========================================

.DEFAULT_GOAL := help

VERILATOR ?= verilator
PYTHON    ?= python3

TOP       := tb_noc_router
RTL_TOP   := noc_router

BUILD_DIR := results/simulation
OBJ_DIR   := $(BUILD_DIR)/obj_router
SIM_EXE   := $(OBJ_DIR)/V$(TOP)

TEST      ?= basic
UNIT      ?= all
SEED      ?= 1
SUITE     ?= smoke
SEEDS     ?= 20

# ------------------------------------------
# RTL sources
# ------------------------------------------

RTL_SRC := \
	rtl/noc_pkg.sv \
	rtl/input_fifo.sv \
	rtl/xy_router.sv \
	rtl/rr_arbiter.sv \
	rtl/crossbar.sv \
	rtl/noc_router.sv

# ------------------------------------------
# Verification sources
# ------------------------------------------

TB_SRC := \
	verification/common/noc_tb_pkg.sv \
	verification/common/noc_input_if.sv \
	verification/common/noc_output_if.sv \
	verification/common/noc_assertions.sv \
	verification/common/noc_driver.sv \
	verification/common/noc_monitor.sv \
	verification/common/noc_scoreboard.sv \
	verification/router/tb_noc_router.sv

TEST_SRC := $(wildcard verification/router/tests/*.svh)

INCLUDES := \
	-Iverification/router/tests

# ------------------------------------------
# Verilator flags
# ------------------------------------------

COMMON_FLAGS := \
	--timing \
	--assert \
	-Wall \
	-Wno-DECLFILENAME

TB_WARNINGS := \
	-Wno-UNUSEDSIGNAL \
	-Wno-UNDRIVEN \
	-Wno-SYNCASYNCNET

LINT_RTL_FLAGS := \
	--lint-only \
	$(COMMON_FLAGS)

LINT_TB_FLAGS := \
	--lint-only \
	$(COMMON_FLAGS) \
	$(TB_WARNINGS)

SIM_FLAGS := \
	--binary \
	-j 4 \
	$(COMMON_FLAGS) \
	$(TB_WARNINGS)

# ------------------------------------------
# Unit test configuration
# ------------------------------------------

UNIT_TESTS := \
	input_fifo \
	xy_router \
	rr_arbiter \
	crossbar

UNIT_DIR := verification/unit
UNIT_BUILD_DIR := $(BUILD_DIR)/unit

# ------------------------------------------
# Lint targets
# ------------------------------------------

.PHONY: help lint lint-rtl build test unit regression clean

lint-rtl:
	$(VERILATOR) $(LINT_RTL_FLAGS) \
		--top-module $(RTL_TOP) \
		$(RTL_SRC)

lint:
	$(VERILATOR) $(LINT_TB_FLAGS) \
		--top-module $(TOP) \
		$(INCLUDES) \
		$(RTL_SRC) $(TB_SRC)

# ------------------------------------------
# Router simulation
# ------------------------------------------

$(SIM_EXE): $(RTL_SRC) $(TB_SRC) $(TEST_SRC) Makefile
	@mkdir -p $(BUILD_DIR)
	$(VERILATOR) $(SIM_FLAGS) \
		--top-module $(TOP) \
		--Mdir $(OBJ_DIR) \
		$(INCLUDES) \
		$(RTL_SRC) $(TB_SRC)

build: $(SIM_EXE)

test: build
	./$(SIM_EXE) +TEST=$(TEST) +SEED=$(SEED)

# ------------------------------------------
# RTL unit tests
# ------------------------------------------

unit:
	@set -e; \
	if [ "$(UNIT)" = "all" ]; then \
		tests="$(UNIT_TESTS)"; \
	else \
		tests="$(UNIT)"; \
	fi; \
	for name in $$tests; do \
		case " $(UNIT_TESTS) " in \
			*" $$name "*) ;; \
			*) echo "ERROR: Unknown unit test '$$name'"; exit 1 ;; \
		esac; \
		echo "======================================"; \
		echo "UNIT TEST: $$name"; \
		echo "======================================"; \
		mkdir -p "$(UNIT_BUILD_DIR)/obj_$$name"; \
		$(VERILATOR) $(SIM_FLAGS) \
			--top-module tb_$$name \
			--Mdir "$(UNIT_BUILD_DIR)/obj_$$name" \
			$(RTL_SRC) \
			"$(UNIT_DIR)/tb_$$name.sv"; \
		"./$(UNIT_BUILD_DIR)/obj_$$name/Vtb_$$name"; \
	done; \
	echo "ALL SELECTED UNIT TESTS PASSED"

# ------------------------------------------
# Regression
# ------------------------------------------

regression:
	$(PYTHON) scripts/sim/regression.py \
		--suite $(SUITE) \
		--seeds $(SEEDS)

# ------------------------------------------
# Cleanup
# ------------------------------------------

clean:
	rm -rf $(BUILD_DIR)
	rm -rf results/coverage
	rm -rf obj_dir
	@echo "Build artifacts cleaned."

# ------------------------------------------
# Help
# ------------------------------------------

help:
	@echo ""
	@echo "NoC Router Verification Commands"
	@echo "--------------------------------------"
	@echo "make lint-rtl                    RTL lint"
	@echo "make lint                        Full testbench lint"
	@echo "make build                       Build router simulator"
	@echo "make test TEST=basic             Run router test"
	@echo "make test TEST=random SEED=42    Run random test"
	@echo "make unit                        Run all RTL unit tests"
	@echo "make unit UNIT=input_fifo        Run one RTL unit test"
	@echo "make regression SUITE=smoke      Smoke regression"
	@echo "make regression SUITE=standard   Directed regression"
	@echo "make regression SUITE=full       Full regression"
	@echo "make clean                       Remove build artifacts"
	@echo ""
