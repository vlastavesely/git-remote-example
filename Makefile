prefix = /usr
bindir = $(prefix)/bin
libdir = $(prefix)/lib
pythondistdir = $(libdir)/python3/dist-packages

.PHONY: test install uninstall

test:
	sh tests/test.sh

install:
	install -m 0755 -d $(bindir) $(pythondistdir)/git_example
	install -m 0755 git-remote-example.py $(bindir)/git-remote-example
	install -m 0644 git_example/*.py $(pythondistdir)/git_example

uninstall:
	rm -f $(bindir)/git-remote-example
	rm -rf $(pythondistdir)/git_example

clean:
	rm -rf git_example/__pycache__
