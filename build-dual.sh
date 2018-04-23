#!/bin/bash
mkdir build-dual
cd build-dual

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
tmpFile="$(mktemp)"
curl -o "${tmpFile}" "https://arch.eckner.net/archlinuxewe/masterkeys.gpg"
pacman-key --add "${tmpFile}"
rm -f "${tmpFile}"
pacman-key --lsign-key 5FDCA472AB93292BC678FD59255A76DB9A12601A
pacman-key --lsign-key F8028D351891AE15970A2B3B3CFB0AD8F60030F8
if ! grep -q "^Server = https://arch\.eckner\.net" /etc/pacman.d/mirrorlist
then
  ml="$(
    curl "https://arch.eckner.net/archlinuxewe/os/any/" 2> /dev/null | \
      tr "<>" "\n\n" | \
      grep "^pacman-mirrorlist-.*\.pkg\.tar\.xz\$" | \
      tail -n1
  )"
  curl "https://arch.eckner.net/archlinuxewe/os/any/${ml}" 2> /dev/null | \
    tar -OxJ etc/pacman.d/mirrorlist > \
    /etc/pacman.d/mirrorlist
fi
if ! grep -q "^\[archlinuxewe\]\$" /etc/pacman.conf
then
  tmpFile="$(mktemp)"
  cat /etc/pacman.conf | \
    (
      while read s
      do
        if [[ "$s" = "# The testing repositories"* ]]
        then
          echo '[archlinuxewe]'
          echo 'SigLevel = Required'
          echo 'Include = /etc/pacman.d/mirrorlist'
          echo ''
        fi
        echo "${s}"
      done
    ) > "${tmpFile}"
  cat "${tmpFile}" > /etc/pacman.conf
  rm -f "${tmpFile}"
fi

sudo pacman --noconfirm -Sy archlinux-keyring archlinux32-keyring
sudo pacman --noconfirm -Su archiso-dual

cat << "__ENDOFARCH32MIRRORLIST__" > /etc/pacman.d/mirrorlist32
Server = https://multiarch.arch32.tyzoid.com/$repo/os/$arch
__ENDOFARCH32MIRRORLIST__

cat << "__MIRRORLIST__" | sudo tee /etc/pacman.d/mirrorlist
Server = https://multiarch.arch32.tyzoid.com/$repo/os/$arch
__MIRRORLIST__

cat << "__ENDOFISOBUILDSCRIPT__" | sudo tee /root/buildiso.sh >/dev/null
#!/bin/bash
/usr/share/archiso/configs/releng/build.sh -v -V"$(date -d"$(date -d "+2day" +%Y-%m-01T12:00:00Z)" +%Y.%m.%d)" -L"ARCH_$(date -d"$(date -d "+2day" +%Y-%m-01T12:00:00Z)" +%Y%m)"
__ENDOFISOBUILDSCRIPT__
chmod +x /root/buildiso.sh
__ENDOFPROVISION.SH__

vagrant up
vagrant ssh -c "sudo reboot";
vagrant ssh -c "sudo bash -c '/root/buildiso.sh'";

vagrant ssh-config > config.txt
scp -rF config.txt default:/home/vagrant/out ../

#vagrant destroy -f
