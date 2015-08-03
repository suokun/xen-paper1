# This is the correct place to edit the build version.
# All other places this is stored (eg. compile.h) should be autogenerated.
export XEN_VERSION       = 4
export XEN_SUBVERSION    = 5
export XEN_EXTRAVERSION ?= .0$(XEN_VENDORVERSION)
export XEN_FULLVERSION   = $(XEN_VERSION).$(XEN_SUBVERSION)$(XEN_EXTRAVERSION)
-include xen-version

export XEN_WHOAMI	?= $(USER)
export XEN_DOMAIN	?= $(shell ([ -x /bin/dnsdomainname ] && /bin/dnsdomainname) || ([ -x /bin/domainname ] && /bin/domainname || echo [unknown]))

export BASEDIR := $(CURDIR)
export XEN_ROOT := $(BASEDIR)/..

EFI_MOUNTPOINT ?= $(BOOT_DIR)/efi

.PHONY: default
default: build

.PHONY: dist
dist: install

.PHONY: build install uninstall clean distclean cscope TAGS tags MAP gtags
build install uninstall debug clean distclean cscope TAGS tags MAP gtags::
ifneq ($(XEN_TARGET_ARCH),x86_32)
	$(MAKE) -f Rules.mk _$@
else
	echo "*** Xen x86/32 target no longer supported!"
endif

.PHONY: _build
_build: $(TARGET)$(CONFIG_XEN_INSTALL_SUFFIX)

.PHONY: _install
_install: D=$(DESTDIR)
_install: T=$(notdir $(TARGET))
_install: Z=$(CONFIG_XEN_INSTALL_SUFFIX)
_install: $(TARGET)$(CONFIG_XEN_INSTALL_SUFFIX)
	[ -d $(D)$(BOOT_DIR) ] || $(INSTALL_DIR) $(D)$(BOOT_DIR)
	$(INSTALL_DATA) $(TARGET)$(Z) $(D)$(BOOT_DIR)/$(T)-$(XEN_FULLVERSION)$(Z)
	ln -f -s $(T)-$(XEN_FULLVERSION)$(Z) $(D)$(BOOT_DIR)/$(T)-$(XEN_VERSION).$(XEN_SUBVERSION)$(Z)
	ln -f -s $(T)-$(XEN_FULLVERSION)$(Z) $(D)$(BOOT_DIR)/$(T)-$(XEN_VERSION)$(Z)
	ln -f -s $(T)-$(XEN_FULLVERSION)$(Z) $(D)$(BOOT_DIR)/$(T)$(Z)
	$(INSTALL_DATA) $(TARGET)-syms $(D)$(BOOT_DIR)/$(T)-syms-$(XEN_FULLVERSION)
	if [ -r $(TARGET).efi -a -n '$(EFI_DIR)' ]; then \
		[ -d $(D)$(EFI_DIR) ] || $(INSTALL_DIR) $(D)$(EFI_DIR); \
		$(INSTALL_DATA) $(TARGET).efi $(D)$(EFI_DIR)/$(T)-$(XEN_FULLVERSION).efi; \
		ln -sf $(T)-$(XEN_FULLVERSION).efi $(D)$(EFI_DIR)/$(T)-$(XEN_VERSION).$(XEN_SUBVERSION).efi; \
		ln -sf $(T)-$(XEN_FULLVERSION).efi $(D)$(EFI_DIR)/$(T)-$(XEN_VERSION).efi; \
		ln -sf $(T)-$(XEN_FULLVERSION).efi $(D)$(EFI_DIR)/$(T).efi; \
		if [ -n '$(EFI_MOUNTPOINT)' -a -n '$(EFI_VENDOR)' ]; then \
			$(INSTALL_DATA) $(TARGET).efi $(D)$(EFI_MOUNTPOINT)/efi/$(EFI_VENDOR)/$(T)-$(XEN_FULLVERSION).efi; \
		elif [ "$(D)" = "$(patsubst $(shell cd $(XEN_ROOT) && pwd)/%,%,$(D))" ]; then \
			echo 'EFI installation only partially done (EFI_VENDOR not set)' >&2; \
		fi; \
	fi

.PHONY: _uninstall
_uninstall: D=$(DESTDIR)
_uninstall: T=$(notdir $(TARGET))
_uninstall: Z=$(CONFIG_XEN_INSTALL_SUFFIX)
_uninstall:
	rm -f $(D)$(BOOT_DIR)/$(T)-$(XEN_FULLVERSION)$(Z)
	rm -f $(D)$(BOOT_DIR)/$(T)-$(XEN_VERSION).$(XEN_SUBVERSION)$(Z)
	rm -f $(D)$(BOOT_DIR)/$(T)-$(XEN_VERSION)$(Z)
	rm -f $(D)$(BOOT_DIR)/$(T)$(Z)
	rm -f $(D)$(BOOT_DIR)/$(T)-syms-$(XEN_FULLVERSION)
	rm -f $(D)$(EFI_DIR)/$(T)-$(XEN_FULLVERSION).efi
	rm -f $(D)$(EFI_DIR)/$(T)-$(XEN_VERSION).$(XEN_SUBVERSION).efi
	rm -f $(D)$(EFI_DIR)/$(T)-$(XEN_VERSION).efi
	rm -f $(D)$(EFI_DIR)/$(T).efi
	rm -f $(D)$(EFI_MOUNTPOINT)/efi/$(EFI_VENDOR)/$(T)-$(XEN_FULLVERSION).efi

.PHONY: _debug
_debug:
	objdump -D -S $(TARGET)-syms > $(TARGET).s

.PHONY: _clean
_clean: delete-unfresh-files
	$(MAKE) -C tools clean
	$(MAKE) -f $(BASEDIR)/Rules.mk -C include clean
	$(MAKE) -f $(BASEDIR)/Rules.mk -C common clean
	$(MAKE) -f $(BASEDIR)/Rules.mk -C drivers clean
	$(MAKE) -f $(BASEDIR)/Rules.mk -C xsm clean
	$(MAKE) -f $(BASEDIR)/Rules.mk -C crypto clean
	$(MAKE) -f $(BASEDIR)/Rules.mk -C arch/$(TARGET_ARCH) clean
	rm -f include/asm *.o $(TARGET) $(TARGET).gz $(TARGET).efi $(TARGET)-syms *~ core
	rm -f include/asm-*/asm-offsets.h
	rm -f .banner

.PHONY: _distclean
_distclean: clean
	rm -f tags TAGS cscope.files cscope.in.out cscope.out cscope.po.out GTAGS GPATH GRTAGS GSYMS

$(TARGET).gz: $(TARGET)
	gzip -f -9 < $< > $@.new
	mv $@.new $@

$(TARGET): delete-unfresh-files
	$(MAKE) -C tools
	$(MAKE) -f $(BASEDIR)/Rules.mk include/xen/compile.h
	[ -e include/asm ] || ln -sf asm-$(TARGET_ARCH) include/asm
	[ -e arch/$(TARGET_ARCH)/efi ] && for f in boot.c runtime.c compat.c efi.h;\
		do ln -nsf ../../../common/efi/$$f arch/$(TARGET_ARCH)/efi/; done;\
		true
	$(MAKE) -f $(BASEDIR)/Rules.mk -C include
	$(MAKE) -f $(BASEDIR)/Rules.mk -C arch/$(TARGET_ARCH) asm-offsets.s
	$(MAKE) -f $(BASEDIR)/Rules.mk include/asm-$(TARGET_ARCH)/asm-offsets.h
	$(MAKE) -f $(BASEDIR)/Rules.mk -C arch/$(TARGET_ARCH) $(TARGET)

# drivers/char/console.o contains static banner/compile info. Blow it away.
# Don't refresh these files during e.g., 'sudo make install'
.PHONY: delete-unfresh-files
delete-unfresh-files:
	@if [ ! -r include/xen/compile.h -o -O include/xen/compile.h ]; then \
		rm -f include/xen/compile.h; \
	fi

.banner: Makefile
	@if which figlet >/dev/null 2>&1 ; then \
		echo " Xen $(XEN_FULLVERSION)" | figlet -f tools/xen.flf > $@.tmp; \
	else \
		echo " Xen $(XEN_FULLVERSION)" > $@.tmp; \
	fi
	@mv -f $@.tmp $@

# compile.h contains dynamic build info. Rebuilt on every 'make' invocation.
include/xen/compile.h: include/xen/compile.h.in .banner
	@sed -e 's/@@date@@/$(shell LC_ALL=C date)/g' \
	    -e 's/@@time@@/$(shell LC_ALL=C date +%T)/g' \
	    -e 's/@@whoami@@/$(XEN_WHOAMI)/g' \
	    -e 's/@@domain@@/$(XEN_DOMAIN)/g' \
	    -e 's/@@hostname@@/$(shell hostname)/g' \
	    -e 's!@@compiler@@!$(shell $(CC) $(CFLAGS) --version 2>&1 | head -1)!g' \
	    -e 's/@@version@@/$(XEN_VERSION)/g' \
	    -e 's/@@subversion@@/$(XEN_SUBVERSION)/g' \
	    -e 's/@@extraversion@@/$(XEN_EXTRAVERSION)/g' \
	    -e 's!@@changeset@@!$(shell tools/scmversion $(XEN_ROOT) || echo "unavailable")!g' \
	    < include/xen/compile.h.in > $@.new
	@cat .banner
	@$(PYTHON) tools/fig-to-oct.py < .banner >> $@.new
	@mv -f $@.new $@

include/asm-$(TARGET_ARCH)/asm-offsets.h: arch/$(TARGET_ARCH)/asm-offsets.s
	@(set -e; \
	  echo "/*"; \
	  echo " * DO NOT MODIFY."; \
	  echo " *"; \
	  echo " * This file was auto-generated from $<"; \
	  echo " *"; \
	  echo " */"; \
	  echo ""; \
	  echo "#ifndef __ASM_OFFSETS_H__"; \
	  echo "#define __ASM_OFFSETS_H__"; \
	  echo ""; \
	  sed -rne "/==>/{s:.*==>(.*)<==.*:\1:; s: [\$$#]: :; p;}"; \
	  echo ""; \
	  echo "#endif") <$< >$@

SUBDIRS = xsm arch/$(TARGET_ARCH) common drivers
define all_sources
    ( find include/asm-$(TARGET_ARCH) -name '*.h' -print; \
      find include -name 'asm-*' -prune -o -name '*.h' -print; \
      find $(SUBDIRS) -name '*.[chS]' -print )
endef

define set_exuberant_flags
    exuberant_flags=`$1 --version 2>/dev/null | (grep -iq exuberant && \
	echo "-I __initdata,__exitdata,__acquires,__releases \
	    -I EXPORT_SYMBOL,EXPORT_SYMBOL_GPL \
	    --extra=+f --c-kinds=+px") || true` 
endef

.PHONY: xenversion
xenversion:
	@echo $(XEN_FULLVERSION)

.PHONY: _TAGS
_TAGS: 
	set -e; rm -f TAGS; \
	$(call set_exuberant_flags,etags); \
	$(all_sources) | xargs etags $$exuberant_flags -a

.PHONY: _tags
_tags: 
	set -e; rm -f tags; \
	$(call set_exuberant_flags,ctags); \
	$(all_sources) | xargs ctags $$exuberant_flags -a

.PHONY: _gtags
_gtags:
	set -e; rm -f GTAGS GSYMS GPATH GRTAGS
	$(all_sources) | gtags -f -

.PHONY: _cscope
_cscope:
	$(all_sources) > cscope.files
	cscope -k -b -q

.PHONY: _MAP
_MAP:
	$(NM) -n $(TARGET)-syms | grep -v '\(compiled\)\|\(\.o$$\)\|\( [aUw] \)\|\(\.\.ng$$\)\|\(LASH[RL]DI\)' > System.map

.PHONY: FORCE
FORCE:

%.o %.i %.s: %.c FORCE
	$(MAKE) -f $(BASEDIR)/Rules.mk -C $(*D) $(@F)

%.o %.s: %.S FORCE
	$(MAKE) -f $(BASEDIR)/Rules.mk -C $(*D) $(@F)

%/: FORCE
	$(MAKE) -f $(BASEDIR)/Rules.mk -C $* built_in.o built_in_bin.o
