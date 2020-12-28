#!/usr/bin/env tclsh

# --------------------------------------------------------------------------
#  exec variant
# --------------------------------------------------------------------------
proc wexec { args } {
    puts "Running $args"
    exec {*}$args >@ stdout 2>@ stderr
}

# --------------------------------------------------------------------------
#  Run a command and grab its output
# --------------------------------------------------------------------------
proc stdout { args } {
    set fin [open "| $args" "r"]
    set res [read $fin]
    close $fin
    return [string trim $res]
}

# --------------------------------------------------------------------------
#  Exit with error message
# --------------------------------------------------------------------------
proc die {msg} {
    puts $msg
    exit 1
}

# --------------------------------------------------------------------------
#  Give up on error
# --------------------------------------------------------------------------
proc dieif { cond msg } {
    if $cond {
	die $msg
    }
}

# --------------------------------------------------------------------------
#  Unknown overload
# --------------------------------------------------------------------------
proc unknown { args } {
    wexec {*}$args
}

# --------------------------------------------------------------------------
#   Info about program usage
# --------------------------------------------------------------------------
proc usage { msg } {
    puts stderr "\n$::argv0 error: $msg"
    puts stderr "\nUsage:"
    puts stderr "\t$::argv0 -m <vm-name> -a <rootfs-tar> \[-s <settings-file>\] \[-f <shared-folders-file>\]"
    exit 1
}

# -- Check if running as root
dieif {[stdout id -u] != 0 } "Only root can run this script !"

# -- Parse arguments
set failed [catch {
    array set ::PARAMS $argv
}]
if { $failed } {
    usage "Failed to parse command line"
}

# -- Globals
set ::VM       $::PARAMS(-m)
set ::TGZ      $::PARAMS(-a)
catch {set ::SETTINGS $::PARAMS(-s)}
catch {set ::SHARED   $::PARAMS(-f)}

if { [info exists ::SETTINGS] } {
    if { ![file exists $::SETTINGS] } {
	usage "VM settings file '${::SETTINGS}' doesn't exist"
    }
    try {
	set fin [open $::SETTINGS "r"]
	while { [gets $fin line] >= 0 } {
	    set line [string trim $line]
	    if { [string match "--*" $line] } {
		lappend ::VMSETTINGS $line
	    }
	}
    } finally {
	close $fin
    }
}
if { [info exists ::SHARED] } {
    if { ![file exists $::SHARED] } {
	usage "VM shared folder file '${::SHARED}' doesn't exist"
    }
    try {
	set fin [open $::SHARED "r"]
	while { [gets $fin line] >= 0 } {
	    set line [string trim $line]
	    if { [string index $line 0] == "#" } {
		continue
	    }
	    lappend ::VMSHARED $line
	}
    } finally {
	close $fin
    }
}

# -- Remove VM is it exists
catch { exec vboxmanage unregistervm "$VM" --delete }

# -- Global variables
set SUITE "stretch"
set IMAGE_PATH "."
set IMAGE_NAME ${SUITE}-${VM}
set IMAGE ${IMAGE_PATH}/${IMAGE_NAME}.img
set MOUNT /mnt/${IMAGE_NAME}

# -- Remove files
file delete -force ${IMAGE_NAME}.img
file delete -force ${IMAGE_NAME}.vdi

# -- Create disk image
puts "Create 4G disk image"
dd if=/dev/zero of=${IMAGE} bs=[expr 1024*1024] count=[expr 4*1024]

# -- Create partition table
puts "Create partition table"
set LOOPDEVICE [stdout losetup --find --show ${IMAGE}]
dieif { $::LOOPDEVICE eq "" } "unable to mount image as loop device"

# to create the partitions programatically (rather than manually)
# we're going to simulate the manual input to fdisk
# The sed script strips off all the comments so that we can
# document what we're doing in-line with the actual commands
# Note that a blank line (commented as "defualt" will send a empty
# line terminated with a newline to take the fdisk default.
set commands [join { o n p 1 "" "" a p w q } "\n"]
catch { fdisk ${LOOPDEVICE} << $commands }
#
#  o # clear the in memory partition table
#  n # new partition
#  p # primary partition
#  1 # partition number 1
#    # default, start immediately after preceding partition
#    # default, extend partition to end of disk
#  a # make a partition bootable
#  p # print the in-memory partition table
#  w # write the partition table
#  q # and we're done
#

# -- Umount
losetup -d ${LOOPDEVICE}

# -- Mount disk
set LOOPDEVICE [stdout losetup --find --show -P ${IMAGE}]

# -- Create file system
puts "Create ext4 filesystem"
mkfs -t ext4 "${LOOPDEVICE}p1"

# -- Mouting first partition
puts "Mounting first partition"
mkdir -p ${MOUNT}
mount "${LOOPDEVICE}p1" ${MOUNT}


# -- untar file system
puts "Unpacking rootfs in ${MOUNT}"
tar -C ${MOUNT} -xvf ${::TGZ}
losetup -d ${LOOPDEVICE}

# -- Compute checksum
ls -l  ${IMAGE}
md5sum ${IMAGE}

# -- Mount disk
set LOOPDEVICE [stdout losetup --find --show -P ${IMAGE}]
mount ${LOOPDEVICE}p1 $MOUNT

# -- Install extlinux mbr
puts "Installing bootloader MBR"
dd bs=440 conv=notrunc count=1 if=/usr/lib/syslinux/mbr/mbr.bin of=${LOOPDEVICE}

# -- Install bootloader config menu
puts "Installing bootloader"
extlinux --install ${MOUNT}
set fout [open "${MOUNT}/extlinux.conf" "w"]
puts $fout "default linux"
puts $fout "timeout 1"
puts $fout "label linux"
puts $fout "kernel /boot/vmlinuz-4.9.0-4-amd64"
puts $fout "append initrd=/boot/initrd.img-4.9.0-4-amd64 root=/dev/sda1 net.ifnames=0"
close $fout

# -- Umount
umount ${MOUNT}
losetup -d ${LOOPDEVICE}

# -- Convert root image
vboxmanage convertfromraw --format vdi --uuid [stdout uuid] ${IMAGE_NAME}.img ${IMAGE_NAME}.vdi

# -- Create virtual machine
vboxmanage createvm --name "${VM}" --ostype Debian_64 --register

# -- Customize VM
if { [info exists ::VMSETTINGS] } {
    foreach line $::VMSETTINGS {
	vboxmanage modifyvm ${VM} {*}$line
    }
}

# -- Add SATA disk controller
vboxmanage storagectl "$VM" --name "${VM}-SATA-CTL" --add sata --controller IntelAHCI

# -- Bind disk to SATA controller
vboxmanage storageattach "$VM" --storagectl "${VM}-SATA-CTL" \
    --port 0 --device 0 --type hdd \
    --medium [file normalize ${IMAGE_NAME}.vdi]

# -- Add IDE disk controller for CDROM
vboxmanage storagectl "$VM" --name "${VM}-IDE-CTL" --add ide

# -- Create shares between VM and host
if { [info exists ::VMSHARED] } {
    foreach kv $::VMSHARED {
	lassign $kv name path
	vboxmanage sharedfolder add $VM --name "$name" --hostpath "$path" --automount
    }
}

# -- Screen resolution
vboxmanage setextradata "$VM" CustomVideoMode1 1920x1080x32

# -- Export to ova
rm -f ${IMAGE_NAME}.img
catch { rm -f "${VM}.ova" }
vboxmanage export "$VM" -o "${VM}.ova"
rm -f ${IMAGE_NAME}.vdi
