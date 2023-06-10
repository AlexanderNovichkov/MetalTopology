format:
	find . -iname '*.h' -o  -iname '*.m' -o -iname '*.metal' | xargs clang-format -i
