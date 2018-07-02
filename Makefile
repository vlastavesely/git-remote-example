LOCALREPO = ../git-local

.PHONY: make-repo

make-repo:
	mkdir -p $(LOCALREPO)
	rm -rf $(LOCALREPO)/*
	rm -rf $(LOCALREPO)/.git
	git -C $(LOCALREPO) init
	echo "/test" >$(LOCALREPO)/.gitignore
	git -C $(LOCALREPO) add .gitignore
	git -C $(LOCALREPO) commit -m "initial"
	echo "GPL-2" >$(LOCALREPO)/COPYING
	git -C $(LOCALREPO) add COPYING
	git -C $(LOCALREPO) commit -m "add COPYING"
	echo "this is a readme" >$(LOCALREPO)/README
	git -C $(LOCALREPO) add README
	git -C $(LOCALREPO) commit -m "add README"
	echo "and this is a new line" >>$(LOCALREPO)/README
	git -C $(LOCALREPO) add README
	git -C $(LOCALREPO) commit -m "update README"
	
