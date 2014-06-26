#
#
#
#

ARCH=i386
TARGET=root3.ramfs.gz
TMPDIR=~/tmp/boot/linuxrescue3
DEBOOT=$(TMPDIR)/files
TESTKERN=2.6.35-rc2.57

all: $(TARGET)

# FIXME - perl module docs with two colons confuses make
#
#.depfiles:
#	find files/ -type l -or -type f -printf "$(TARGET): %p\n" >$@
#
#include .depfiles

debcache:
	rm -rf $(DEBOOT)
	cp -a $(TMPDIR)/deb $(DEBOOT)

debcache_save:
	mkdir -p $(TMPDIR)/deb
	cp -u $(DEBOOT)/var/cache/apt/archives/* $(TMPDIR)/deb

# TODO:
# packages:
#	sysklogd, binutils(ar), chvt, clamscan, lspci, showkey,n2n,
#	avahi-utils, bind9-host, pcap-drone,
# busybox for many things
debootstrap:
	mkdir -p $(DEBOOT)
	sudo /usr/sbin/debootstrap \
		--arch=$(ARCH) --variant=minbase \
		--include=ifupdown,udhcpc,iproute,netcat-openbsd,iputils-ping,procps,btrfs-tools,dmraid,kexec-tools,mdadm,xfsprogs,xfsdump,vlan,lvm2,cpufrequtils,elvis-console,extlinux,ht,htop,ipmitool,less,lshw,mathomatic,ntfsprogs,psmisc,pv,rsync,openssh-client,screen,socat,strace,iputils-tracepath,traceroute,wget,whiptail,wodim,zip,batmand,chntpw,debootstrap,ethtool,iptraf,partimage,partimage-server,testdisk,powertop,tcpdump,dropbear,mc,kpartx \
		squeeze \
		$(DEBOOT)/ \
		http://ftp.au.debian.org/debian/
	sudo chown -R $(LOGNAME) $(DEBOOT)
	chmod -R a+r $(DEBOOT)

findlinks:
	find $(DEBOOT) -type f -links +1 -ls

# FIXME - teach the gen_init_cpio stuff to find and create hard links
fixlinks:
	ln -fs perl5.10.1 $(DEBOOT)/usr/bin/perl
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

# FIXME - use the gen_init_cpio stuff properly to create dev nodes
fixdev:
	rm -f $(DEBOOT)/dev/tty[123456] $(DEBOOT)/dev/ttyS0
	sudo mknod $(DEBOOT)/dev/tty1 c 4 1
	sudo mknod $(DEBOOT)/dev/tty2 c 4 2
	sudo mknod $(DEBOOT)/dev/tty3 c 4 3
	sudo mknod $(DEBOOT)/dev/tty4 c 4 4
	sudo mknod $(DEBOOT)/dev/tty5 c 4 5
	sudo mknod $(DEBOOT)/dev/tty6 c 4 6
	sudo mknod $(DEBOOT)/dev/ttyS0 c 4 64

fixup: fixlinks fixdev
	ln -fs sbin/init $(DEBOOT)
	perl -pi -e 's/:\*:/::/' $(DEBOOT)/etc/shadow
	perl -pi -e 's/^#T0:/T0:/' $(DEBOOT)/etc/inittab
	perl -pi -e 's/(ttyS0 9600) vt100/$$1 xterm/' $(DEBOOT)/etc/inittab
	rm -rf \
		$(DEBOOT)/etc/hostname \
		$(DEBOOT)/dev/.udev \
		$(DEBOOT)/etc/ssh/ssh_host_*_key*
	rm -f $(DEBOOT)/usr/bin/mesg
	echo "#!/bin/sh" >$(DEBOOT)/usr/bin/mesg
	echo "true" >>$(DEBOOT)/usr/bin/mesg
	chmod a+x $(DEBOOT)/usr/bin/mesg

customise: busybox
	echo "color normal white on black" >>$(DEBOOT)/etc/elvis/elvis.clr

find_busybox_dupes:
	cd $(DEBOOT); \
	for i in $$( ( \
		ls --indicator-style=none busybox/; \
		ls --indicator-style=none bin/; \
		ls --indicator-style=none sbin/; \
		ls --indicator-style=none usr/bin/; \
		ls --indicator-style=none usr/sbin/ \
	) |sort |uniq -d); do \
		echo $$(find busybox bin sbin usr/bin usr/sbin |grep /$$i$$); \
	done 

BB_BIN := \
	cat chgrp chmod chown cpio date df dmesg echo egrep false fgrep \
	gunzip gzip hostname kill ln mkdir mknod mktemp mv netstat pidof \
	pwd readlink rm rmdir sleep stty sync true uname uncompress zcat
BB_SBIN := \
	blockdev ifconfig losetup nameif route swapoff swapon 
BB_USRBIN := \
	basename clear cmp cut dirname env expr head ionice killall last \
	logname md5sum mkfifo printf renice reset sha1sum sha512sum sort \
	tail touch tty watch wc whoami yes \
	du id logger tee tr uniq uptime which \
	free test [ unxz xz xzcat \
	getopt
busybox:
	mkdir -p $(DEBOOT)/busybox
	qemu-$(ARCH) -L $(DEBOOT) $(DEBOOT)/bin/busybox --install -s $(DEBOOT)/busybox
	perl -pi -e 's{(bin:/bin)}{$$1:/busybox}' $(DEBOOT)/etc/profile
	cd $(DEBOOT)/busybox; mv -f $(BB_BIN) ../bin
	cd $(DEBOOT)/busybox; mv -f $(BB_SBIN) ../sbin
	cd $(DEBOOT)/busybox; mv -f $(BB_USRBIN) ../usr/bin

DEL_BIN := \
	dir gzexe lessecho lesskey vdir zcmp zdiff zegrep zfgrep \
	zforce zgrep zless zmore znew
DEL_SBIN := \
	btrfs-debug-tree btrfs-image btrfs-map-logical btrfs-vol btrfsctl \
	dumpe2fs e2image isosize lvmconf mkfs.bfs mkfs.cramfs mkfs.minix \
	mkhomedir_helper pam_tally pam_tally2 plipconfig rarp raw rtacct \
	rtmon shadowconfig slattach ss wipefs xfs_repair xfsdump xfsrestore \
	
DEL_USRBIN := \
	addpart apt-cdrom apt-mark bashbug captoinfo catchsegv chfn \
	chsh clear_console comm ddate expand \
	expiry factor faillog fmt fold getent groups hostid infotocap \
	ipcmk ipcrm ipcs line link locale lzmainfo mcookie \
	ncurses5-config ncursesw5-config newgrp nl nproc ntfscluster ntfscmp \
	od paste pathchk pg pmap prtstat pwdx rename.ul rev runcon setsid \
	sha224sum sha256sum sha384sum skill snice ssh-argv0 stdbuf tabs \
	tac taskset toe tsort unexpand unlink usb-devices users wall whereis \
	zdump sg
DEL_USRBIN += \
	apt-key chage chcon csplit filan gpasswd gpg gpgsplit gpg-zip gpgv \
	iconv infocmp join localedev lspgpot oldfind omshell pcretest pr \
	procan ptx readom shuf ssh-keyscan ssh-vulnkey stduf \
	tic top who zipcloak zipnote zipsplit

minimise: debcache_save
	cd $(DEBOOT)/bin; echo $(DEL_BIN) | xargs rm -f
	cd $(DEBOOT)/bin; echo $(DEL_SBIN) | xargs rm -f
	cd $(DEBOOT)/usr/bin; echo $(DEL_USRBIN) | xargs rm -f
	rm -rf \
		$(DEBOOT)/lib/udev/keymaps/* \
		$(DEBOOT)/sbin/fsck.cramfs \
		$(DEBOOT)/sbin/fsck.minix \
		$(DEBOOT)/sbin/ldconfig \
		$(DEBOOT)/sbin/mdmon \
		$(DEBOOT)/usr/lib/gconv/* \
		$(DEBOOT)/usr/lib/i486/* \
		$(DEBOOT)/usr/lib/i586/* \
		$(DEBOOT)/usr/lib/i686/* \
		$(DEBOOT)/usr/lib/libX11.so.6.3.0 \
		$(DEBOOT)/usr/lib/libxml2.so.2.7.8 \
		$(DEBOOT)/usr/sbin/xfs_db \
		$(DEBOOT)/usr/sbin/xfs_io \
		$(DEBOOT)/usr/sbin/xfs_logprint \
		$(DEBOOT)/usr/sbin/xfs_mdrestore \
		$(DEBOOT)/usr/share/common-licenses/* \
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
		$(DEBOOT)/usr/share/mc/mc.hint* \
		$(DEBOOT)/usr/share/mc/mc.hlp* \
		$(DEBOOT)/usr/share/mc/syntax/* \
		$(DEBOOT)/usr/share/zoneinfo/* \
		$(DEBOOT)/usr/share/X11/locale/* \
		$(DEBOOT)/usr/share/screen/utf8encodings/* \
		$(DEBOOT)/var/cache/apt/archives/* \
		$(DEBOOT)/var/cache/debconf/* \
		$(DEBOOT)/var/lib/apt/lists/* \
		$(DEBOOT)/var/lib/dpkg/*-old \
		$(DEBOOT)/var/lib/dpkg/info/*.symbols \
		$(DEBOOT)/var/lib/dpkg/info/*.templates \
		$(DEBOOT)/var/lib/dpkg/info/*.md5sums \
		$(DEBOOT)/var/lib/dpkg/info/openssh-client.preinst \
		$(DEBOOT)/var/log/* \

bootstrap: debootstrap minimise fixup customise

$(TARGET): gen_init_cpio
	./gen_initramfs_list.sh -o $@ -u squash -g squash $(DEBOOT)/

test: 	$(TARGET) $(TESTKERN)
	kvm \
		-m 384 \
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
	rm -f $(TARGET) test.iso .depfiles
	rm -rf $(DEBOOT)


