#!/bin/bash
mkdir build-i686
cd build-i686

cat << "END" > Vagrantfile
Vagrant.configure("2") do |config|
  config.vm.box = "archlinux/archlinux"
  config.vm.provision "shell", path: "provision.sh", run: "once"
end
END

cat << "__ENDOFPROVISION.SH__" > provision.sh
#!/bin/bash
set -e
ln -svf /usr/share/zoneinfo/America/Detroit /etc/localtime

pacman --noconfirm -Sy archlinux-keyring

tee -a /etc/pacman.conf << "_PACMANCONF_"
[releng]
Include = /etc/pacman.d/mirrorlist32
_PACMANCONF_

cat << "__ENDOFARCH32MIRRORLIST__" > /etc/pacman.d/mirrorlist32
Server = https://32.arlm.tyzoid.com/$arch/$repo
Server = http://arch32.mirrors.simplysam.us/$arch/$repo
Server = https://mirror.archlinux32.org/$arch/$repo
__ENDOFARCH32MIRRORLIST__

pacman --noconfirm -Sy archlinux32-keyring-transition
pacman --noconfirm -R archlinux32-keyring-transition
pacman --noconfirm -S archlinux32-keyring
pacman --noconfirm -Syu archiso32

cat << "__ENDOFISOBUILDSCRIPT__" | tee /root/buildiso.sh >/dev/null
#!/bin/bash
/usr/share/archiso/configs/releng/build.sh -v -V"$(date -d"$(date -d "+2day" +%Y-%m-01T12:00:00Z)" +%Y.%m.%d)" -L"ARCH_$(date -d"$(date -d "+2day" +%Y-%m-01T12:00:00Z)" +%Y%m)"
__ENDOFISOBUILDSCRIPT__
chmod +x /root/buildiso.sh
__ENDOFPROVISION.SH__

vagrant up
vagrant ssh -c "sudo reboot";
vagrant ssh -c 'sudo bash -c "/root/buildiso.sh"';

vagrant ssh-config > config.txt
scp -rF config.txt default:/home/vagrant/out ../

#vagrant destroy -f
