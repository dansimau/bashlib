.PHONY: out
out: bash.md

bash.md: bash.sh
	./gen-docs.sh >bash.md

.PHONY: test
test:
	./test-bash.sh
