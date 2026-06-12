EMACS ?= emacs

LOAD_PATH = -L . -L tests

SRC_FILES = \
	easyob-utils.el \
	easyob-exec.el \
	easyob-session.el \
	easyob-def.el \
	easyob.el

TEST_FILES = \
	tests/easyob-tests.el \
	tests/easyob-utils-tests.el \
	tests/easyob-exec-tests.el \
	tests/easyob-session-tests.el \
	tests/easyob-def-tests.el

TEST_LOAD = $(addprefix -l ,$(basename $(notdir $(SRC_FILES) $(TEST_FILES))))

# 生成 .elc 的隐式规则
%.elc: %.el
	$(EMACS) -Q --batch $(LOAD_PATH) -f batch-byte-compile $<

.PHONY: test clean compile

# 编译所有源文件和测试文件
compile: $(SRC_FILES:.el=.elc) $(TEST_FILES:.el=.elc)

# 运行测试（先编译再测试，保证用的是最新代码）
test: compile
	$(EMACS) -Q --batch $(LOAD_PATH) $(TEST_LOAD) \
		-f ert-run-tests-batch-and-exit

clean:
	rm -f $(SRC_FILES:.el=.elc) $(TEST_FILES:.el=.elc)
