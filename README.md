# make-vm
Create virtual machines from command line

These tools relies on `virtualbox` which must be installed on the computer. The scripts make use of `vboxmanage` which is the command line utility of `virtualbox`.

## Installing VirtualBox

On debian buster VirtualBox is not officially supported. There are unofficial debian packages on buster which are available, see below :

~~~~
localadmin@buster:~/vincent/make-vm$ cat /etc/apt/sources.list.d/virtualbox-unofficial.list 
deb [trusted=yes] https://people.debian.org/~lucas/virtualbox-buster/ ./
~~~~


## Running the script

