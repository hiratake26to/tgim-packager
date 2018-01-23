#
# This Makefile is used for debugging only.
#

dummy:

.PHONY: test

test:
	./tgim-pack pack test/tgim-pack.config.json
