EMACS ?= emacs

# 如果需要额外的依赖路径，可以在这里添加 -L 参数
LOAD_PATH = -L . -L tests

# 测试文件列表，按依赖顺序加载
TEST_FILES = \
	-l easyob-tests \
	-l easyob-utils-tests \
	-l easyob-exec-tests \
	-l easyob-session-tests \
	-l easyob-def-tests

.PHONY: test clean

test:
	$(EMACS) -Q --batch $(LOAD_PATH) $(TEST_FILES) \
		-f ert-run-tests-batch-and-exit

clean:
	rm -f *.elc tests/*.elc
