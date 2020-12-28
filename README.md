# make-vm
Create virtual machines from command line

These tools relies on `virtualbox` which must be installed on the computer. The scripts make use of `vboxmanage` which is the command line utility of `virtualbox`.

## Installing VirtualBox

On debian buster VirtualBox is not officially supported. There are unofficial debian packages on buster which are available, see below :

~~~~
localadmin@buster:~/vincent/make-vm$ cat /etc/apt/sources.list.d/virtualbox-unofficial.list 
deb [trusted=yes] https://people.debian.org/~lucas/virtualbox-buster/ ./
~~~~

Here are the required packages :

~~~~
localadmin@buster:~/vincent/make-vm$ dpkg -l | fgrep virtualbox
ii  virtualbox                             6.1.14-dfsg-4~~bpo10+1              amd64        x86 virtualization solution - base binaries
ii  virtualbox-dkms                        6.1.14-dfsg-4~~bpo10+1              amd64        x86 virtualization solution - kernel module sources for dkms
ii  virtualbox-guest-dkms                  6.1.14-dfsg-4~~bpo10+1              all          x86 virtualization solution - guest addition module source for dkms
ii  virtualbox-guest-utils                 6.1.14-dfsg-4~~bpo10+1              amd64        x86 virtualization solution - non-X11 guest utilities
ii  virtualbox-qt                          6.1.14-dfsg-4~~bpo10+1              amd64        x86 virtualization solution - Qt based user interface
~~~~

## Running the script

The script will convert a tar.gz archive to an OVA file.
