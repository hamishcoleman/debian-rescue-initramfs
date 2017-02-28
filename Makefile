#
#
# TODO:
# xz --check=crc32 --lzma2=dict=1MiB
#

# Typical workflow:
#  make clean debcache
#  make bootstrap
#  make test
#

MIRROR=http://httpredir.debian.org/debian
ARCH=i386
QEMU_ARCH=i386
TARGET=root3.ramfs.gz
TMPDIR=$(HOME)/tmp/boot/linuxrescue3
DEBOOT=$(TMPDIR)/files
SAVEPERM=$(TMPDIR)/fakeroot.save
TESTKERN=4.6-15

# Not simply user changable - the minimisation process will break differently
# for other debian versions, so the fixup process will need adjustments
VERSION=jessie

fakeroot=fakeroot -i $(SAVEPERM) -s $(SAVEPERM)

all: $(TARGET)

# FIXME - perl module docs with two colons confuses make
#
#.depfiles:
#	find files/ -type l -or -type f -printf "$(TARGET): %p\n" >$@
#
#include .depfiles

$(TMPDIR):
	mkdir -p $(TMPDIR)

$(DEBOOT):
	mkdir -p $(DEBOOT)

# Install the cached downloads
debcache: $(TMPDIR) $(DEBOOT)
	rm -rf $(DEBOOT)
	rm -rf $(SAVEPERM)
	mkdir -p $(TMPDIR)/cache/archives
	mkdir -p $(TMPDIR)/cache/lists
	mkdir -p $(DEBOOT)/var/cache/apt/archives/
	mkdir -p $(DEBOOT)/var/lib/apt/lists/
	-cp -a $(TMPDIR)/cache/archives/*_all.deb $(DEBOOT)/var/cache/apt/archives/
	-cp -a $(TMPDIR)/cache/archives/*_$(ARCH).deb $(DEBOOT)/var/cache/apt/archives/
	cp -a $(TMPDIR)/cache/lists/ $(DEBOOT)/var/lib/apt/


# Save the downloaded archives from the bootstrap image
debcache_save: $(TMPDIR) $(DEBOOT)
	mkdir -p $(TMPDIR)/cache
	cp -a $(DEBOOT)/var/cache/apt/archives $(TMPDIR)/cache
	cp -a $(DEBOOT)/var/lib/apt/lists $(TMPDIR)/cache

# TODO:
# packages:
#	sysklogd, binutils(ar), chvt, clamscan, lspci, showkey,n2n,
#	avahi-utils, bind9-host, pcap-drone,
#	iotop,
#	tcc
# busybox for many things
# avoid sudo

SPACE :=
SPACE +=
COMMA :=,

packages := $(shell egrep -v "^\#" packages.txt)

debootstrap: $(DEBOOT) packages.txt
	mkdir -p $(DEBOOT)
	sudo /usr/sbin/qemu-debootstrap \
		--arch=$(ARCH) --variant=minbase \
		--include=$(subst $(SPACE),$(COMMA),$(packages)) \
		jessie \
		$(DEBOOT)/ \
		$(MIRROR)

multistrap.conf: packages.txt
	echo "[General]" >$@
	echo "bootstrap=DebianRescue" >>$@
	echo "aptsources=DebianRescue" >>$@
	echo "configscript=multistrap.configscript" >>$@

	echo "[DebianRescue]" >>$@
	echo "source=$(MIRROR)" >>$@
	echo "suite=jessie" >>$@
	echo "keyring=debian-archive-keyring" >>$@
	echo packages=`egrep -v "^\#" $^` >>$@

multistrap: $(DEBOOT) multistrap.conf
	mkdir -p $(DEBOOT)/dev
	sudo mknod $(DEBOOT)/dev/urandom c 1 9
	sudo /usr/sbin/multistrap \
		-a $(ARCH) -d $(DEBOOT) -f multistrap.conf
	sudo chroot $(DEBOOT) ./multistrap.configscript
	sudo kill -9 `sudo lsof -Fp $(DEBOOT) | tr -d p`
	-sudo umount $(DEBOOT)/proc
	sudo rm -f $(DEBOOT)/multistrap.configscript

# TODO - make multistrap.configscript smarter and remove the kill+umount here

# Extract the permissions from the actual filesystem into the fakeroot
# database.  Which allows us to chown/chmod the whole dir tree to the
# unprivileged user
#
save_perms:
	sudo find $(DEBOOT) -printf "%y %m %u %g %p\n" >tmp.perms
	sudo chown -R $(LOGNAME) $(DEBOOT)
	chmod -R a+r $(DEBOOT)
	$(fakeroot) bash -c 'cat tmp.perms | egrep "^[df]" | while read y m u g p; do chown $$u:$$g $$p; chmod $$m $$p; done'
	rm -f tmp.perms



# hack to reinsert elvis-console, but it is only ~200k smaller...
install.elvis.hack:
	cp elvis-common_2.2.0-11.1_all.deb elvis-console_2.2.0-11.1_i386.deb $(DEBOOT)
	sudo /usr/sbin/chroot $(DEBOOT) dpkg -i elvis*2.2.0*
	rm $(DEBOOT)/elvis-common_2.2.0-11.1_all.deb $(DEBOOT)/elvis-console_2.2.0-11.1_i386.deb
	sudo chown -R $(LOGNAME) $(DEBOOT)
	chmod -R a+r $(DEBOOT)

findlinks: $(DEBOOT)
	find $(DEBOOT) -type f -links +1 -ls

# FIXME - teach the gen_init_cpio stuff to find and create hard links
fixlinks: $(DEBOOT)
	ln -fs perl5.20.2 $(DEBOOT)/usr/bin/perl
	ln -fs agetty $(DEBOOT)/sbin/getty
	ln -fs tune2fs $(DEBOOT)/sbin/e2label
	ln -fs e2fsck $(DEBOOT)/sbin/fsck.ext2
	ln -fs e2fsck $(DEBOOT)/sbin/fsck.ext3
	ln -fs e2fsck $(DEBOOT)/sbin/fsck.ext4
	ln -fs e2fsck $(DEBOOT)/sbin/fsck.ext4dev
	ln -fs mke2fs $(DEBOOT)/sbin/mkfs.ext2
	ln -fs mke2fs $(DEBOOT)/sbin/mkfs.ext3
	ln -fs mke2fs $(DEBOOT)/sbin/mkfs.ext4
	ln -fs mke2fs $(DEBOOT)/sbin/mkfs.ext4dev
	ln -fs domainname $(DEBOOT)/bin/nisdomainname
	ln -fs domainname $(DEBOOT)/bin/ypdomainname
	ln -fs domainname $(DEBOOT)/bin/dnsdomainname
	ln -fs ifup $(DEBOOT)/sbin/ifdown
	ln -fs ../bin/true $(DEBOOT)/sbin/ldconfig

# FIXME - use the gen_init_cpio stuff properly to create dev nodes
fixdev: $(DEBOOT)
	rm -f $(DEBOOT)/dev/tty[123456] $(DEBOOT)/dev/ttyS0
	$(fakeroot) mknod $(DEBOOT)/dev/tty1 c 4 1
	$(fakeroot) mknod $(DEBOOT)/dev/tty2 c 4 2
	$(fakeroot) mknod $(DEBOOT)/dev/tty3 c 4 3
	$(fakeroot) mknod $(DEBOOT)/dev/tty4 c 4 4
	$(fakeroot) mknod $(DEBOOT)/dev/tty5 c 4 5
	$(fakeroot) mknod $(DEBOOT)/dev/tty6 c 4 6
	$(fakeroot) mknod $(DEBOOT)/dev/ttyS0 c 4 64

# fixups are things that are needed to make the image actually work
#
fixup: $(DEBOOT) fixlinks fixdev
	ln -fs sbin/init $(DEBOOT)
	perl -pi -e 's/:\*:/::/' $(DEBOOT)/etc/shadow
	perl -pi -e 's/^#T0:/T0:/' $(DEBOOT)/etc/inittab
	perl -pi -e 's/(ttyS0 9600) vt100/$$1 xterm/' $(DEBOOT)/etc/inittab
	perl -pi -e 's/--no-headers --format args/-o args/' $(DEBOOT)/etc/init.d/udev
	perl -pi -e 's/--load=/-p /' $(DEBOOT)/etc/init.d/procps
	perl -pi -e 's/sleep 30//' $(DEBOOT)/etc/init.d/udev
	rm -rf \
		$(DEBOOT)/etc/hostname \
		$(DEBOOT)/dev/.udev \
		$(DEBOOT)/dev/fd \
		$(DEBOOT)/etc/ssh/ssh_host_*_key*
	cp zero_byte_exe $(DEBOOT)/bin/true
	cp zero_byte_exe $(DEBOOT)/usr/bin/mesg
	cp zero_byte_exe $(DEBOOT)/usr/bin/locale
	ln -sf /proc/mounts $(DEBOOT)/etc/mtab
	mkdir -p $(DEBOOT)/var/log/fsck
	perl -pi -e 's/START_DAEMON=true/START_DAEMON=false/' $(DEBOOT)/etc/default/mdadm

# some unneeded things that just cause warnings
fix_warnings: $(DEBOOT)
	rm -f \
		$(DEBOOT)/etc/init.d/loadcpufreq \
		$(DEBOOT)/etc/rc*.d/*loadcpufreq \
		$(DEBOOT)/etc/init.d/mountoverflowtmp \
		$(DEBOOT)/etc/rc*.d/*mountoverflowtmp \
		$(DEBOOT)/etc/rc*.d/*ipmievd \

# customisations are things that go beyond makeing the image work
#
customise: $(DEBOOT) busybox fix_warnings
	mkdir -p $(DEBOOT)/etc/elvis/
	echo "color normal white on black" >>$(DEBOOT)/etc/elvis/elvis.clr
	echo "rescue" >$(DEBOOT)/etc/hostname
	ln -sf /usr/bin/less $(DEBOOT)/bin/more
	echo "" >>$(DEBOOT)/etc/network/interfaces
	echo "iface eth0 inet dhcp" >>$(DEBOOT)/etc/network/interfaces
	echo "iface wlan0 inet manual" >>$(DEBOOT)/etc/network/interfaces
	echo "    wpa-roam /etc/wpa_supplicant/wpa_supplicant.conf" >>$(DEBOOT)/etc/network/interfaces
	echo "iface default inet dhcp" >>$(DEBOOT)/etc/network/interfaces
	echo "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev" >$(DEBOOT)/etc/wpa_supplicant/wpa_supplicant.conf
	echo "update_config=1" >>$(DEBOOT)/etc/wpa_supplicant/wpa_supplicant.conf
	echo "e scr.utf8 = true" >$(DEBOOT)/usr/share/radare2/radare2rc

find_busybox_dupes: $(DEBOOT)
	cd $(DEBOOT); \
	for i in $$( ( \
		ls --indicator-style=none busybox/; \
		find bin/ sbin/ usr/bin/ usr/sbin/ -type f -printf "%f\n"; \
	) |sort |uniq -d); do \
		echo $$(find busybox bin sbin usr/bin usr/sbin |grep /$$i$$); \
	done 

BB_BIN := \
	cat chgrp chmod chown cpio date df dmesg echo egrep false fgrep \
	gunzip gzip hostname kill ln mkdir mknod mktemp more mv nc netstat \
	pidof pwd readlink rm rmdir sleep stty sync uname uncompress \
	zcat dnsdomainname mount ps sed umount \
    ping6
BB_SBIN := \
	blockdev ifconfig losetup nameif route swapoff swapon sysctl \
	modprobe vconfig mkswap \
    switch_root start-stop-daemon pivot_root
BB_USRBIN := \
	basename clear cmp cut dirname env expr head ionice killall last \
	logname md5sum mkfifo printf renice reset sha1sum sha512sum sort \
	tail touch tty watch wc whoami yes \
	du id logger tee tr uniq uptime which \
	free test [ unxz xz xzcat \
	getopt xargs timeout stat seq \
    realpath
BB_USRSBIN := \
	chroot

busybox: $(DEBOOT)
	mkdir -p $(DEBOOT)/busybox
	qemu-$(QEMU_ARCH) -L $(DEBOOT) $(DEBOOT)/bin/busybox --install -s $(DEBOOT)/busybox
	cd $(DEBOOT)/busybox; for i in *; do ln -sf /bin/busybox $$i; done
	perl -pi -e 's{(bin:/bin)}{$$1:/busybox}' $(DEBOOT)/etc/profile
	echo "NOSWAP=yes" >> $(DEBOOT)/etc/default/rcS
	echo "unset QUIET_SYSCTL" >> $(DEBOOT)/etc/default/rcS
	cd $(DEBOOT)/busybox; mv -f $(BB_BIN) ../bin
	cd $(DEBOOT)/busybox; mv -f $(BB_SBIN) ../sbin
	cd $(DEBOOT)/busybox; mv -f $(BB_USRBIN) ../usr/bin
	cd $(DEBOOT)/busybox; mv -f $(BB_USRSBIN) ../usr/sbin

minimise: $(DEBOOT) debcache_save
	unset NO; \
	echo "\n\nRunning package scripts for minimise phase"; \
	echo -n "\nMinimising:\n\t"; \
        for package in `dpkg-query --admindir=$(DEBOOT)/var/lib/dpkg --show --showformat='$${Package}\n'`; do \
            if [ -x packages/$$package ]; then \
		echo -n "$$package "; \
                packages/$$package $(DEBOOT) $(ARCH) minimise; \
            else \
		NO="$$NO$$package "; \
            fi; \
	done; \
        echo "\n\nNo script:\n\t$$NO\n"
	rm -rf \
		$(DEBOOT)/lib/udev/keymaps/* \
		$(DEBOOT)/usr/lib/i486/* \
		$(DEBOOT)/usr/lib/i586/* \
		$(DEBOOT)/usr/lib/i686/* \
		$(DEBOOT)/usr/lib/libX11.so.6.3.0 \
		$(DEBOOT)/usr/lib/libdb-4.8.so \
		$(DEBOOT)/usr/lib/libxml2.so.2.7.8 \
		$(DEBOOT)/usr/lib/locale/* \
		$(DEBOOT)/usr/share/doc/* \
		$(DEBOOT)/usr/share/doc/* \
		$(DEBOOT)/usr/share/info/* \
		$(DEBOOT)/usr/share/lintian/* \
		$(DEBOOT)/usr/share/elvis/tags \
		$(DEBOOT)/usr/share/elvis/elvis.glade \
		$(DEBOOT)/usr/share/elvis/manual \
		$(DEBOOT)/usr/share/elvis/stubs \
		$(DEBOOT)/usr/share/elvis/elvis.gnome \
		$(DEBOOT)/usr/share/locale/* \
		$(DEBOOT)/usr/share/man/* \
		$(DEBOOT)/usr/share/X11/locale/* \
		$(DEBOOT)/usr/share/radare2/0.9.6/debootstrap* \
		$(DEBOOT)/var/cache/apt/archives/* \
		$(DEBOOT)/var/cache/apt/pkgcache.bin \
		$(DEBOOT)/var/cache/apt/srcpkgcache.bin \
		$(DEBOOT)/var/cache/debconf/* \
		$(DEBOOT)/var/lib/apt/lists/* \
		$(DEBOOT)/var/lib/dpkg/*-old \
		$(DEBOOT)/var/lib/dpkg/info/*.symbols \
		$(DEBOOT)/var/lib/dpkg/info/*.templates \
		$(DEBOOT)/var/lib/dpkg/info/*.md5sums \
		$(DEBOOT)/var/lib/dpkg/info/openssh-client.preinst \
		$(DEBOOT)/var/log/* \

bootstrap: multistrap save_perms minimise fixup customise

$(TARGET): $(DEBOOT) gen_init_cpio gen_initramfs_list.sh
	$(fakeroot) ./gen_initramfs_list.sh -o $@ -u squash -g squash $(DEBOOT)/

test: 	$(TARGET) $(TESTKERN)
	qemu-system-i386 -enable-kvm \
		-m 512 \
		-serial stdio \
		-append console=ttyS0 \
		-kernel $(TESTKERN) -initrd $(TARGET)

#test.iso: $(TARGET)
#	mkisofs -o $@ \
#		-c isolinux/boot.cat \
#		-b isolinux/isolinux.bin -no-emul-boot -boot-load-size 32 \
#		-boot-info-table \
#		-max-iso9660-filenames -N -D \
#		-d -allow-leading-dots -relaxed-filenames -allow-multidot \
#		-iso-level 3 \
#		-J \
#		-R \
#		-graft-points \
#		test $(TARGET)
#
#test_cdrom: test.iso
#	kvm -cdrom test.iso 

clean:
	rm -f $(TARGET) multistrap.conf test.iso .depfiles
	rm -rf $(DEBOOT)


