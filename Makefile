PREFIX ?= localinstall

ifeq ($(shell uname),Darwin)
	INSTALL=ginstall
else
	INSTALL=install
endif

share/man/man7/git-colon-paths.7: share/man/man7/git-colon-paths.org
	pandoc -s -f org -t man $< -o $@
share/man/man1/git-colon-paths.1: share/man/man1/git-colon-paths.org
	pandoc -s -f org -t man $< -o $@

.PHONY: test
test:
	python3 test/test_gcps_comp.py


doc:share/man/man1/git-colon-paths.1 share/man/man7/git-colon-paths.7

install: doc
	$(INSTALL) -D share/man/man1/git-colon-paths.1 $(DESTDIR)$(PREFIX)/share/man/man1/git-colon-paths.1
	$(INSTALL) -D share/man/man7/git-colon-paths.7 $(DESTDIR)$(PREFIX)/share/man/man7/git-colon-paths.7
	$(INSTALL) -D etc/profile.d/git-colon-path-support.bash $(DESTDIR)$(PREFIX)/etc/profile.d/git-colon-path-support.bash
	$(INSTALL) -D etc/profile.d/git-colon-path-support.zsh $(DESTDIR)$(PREFIX)/etc/profile.d/git-colon-path-support.zsh

clean:
	rm -vf share/man/man7/git-colon-paths.7
