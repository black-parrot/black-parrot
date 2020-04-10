###

TEST_FILE ?= test.S

MICROCODE_DIR ?= $(abspath ../microcode/cce)

.DEFAULT: echo

echo:
	@echo "Usage: make test"
	@echo "Usage: make test TEST_FILE=<filename>.S"
	@echo "MICROCODE_DIR: $(MICROCODE_DIR)"

test:
	python2 test.py -o $(TEST_FILE)
	cp test.S $(MICROCODE_DIR)/$(TEST_FILE)

clean:
	rm -f $(TEST_FILE) $(MICROCODE_DIR)/$(TEST_FILE)

