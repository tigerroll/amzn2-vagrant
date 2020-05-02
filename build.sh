#!/usr/bin/env bash

# grobal definition.
base_url="https://cdn.amazonlinux.com/os-images/latest/"
release="$(curl -D - -s  -o /dev/null ${base_url} | grep location | awk -F/ '{print $(NF-1)}')"
vdi_name="amzn2-virtualbox-${release}-x86_64.xfs.gpt.vdi"
virtualbox_url="https://cdn.amazonlinux.com/os-images/${release}/virtualbox/${vdi_name}"
public_key="$(curl -s https://raw.githubusercontent.com/hashicorp/vagrant/master/keys/vagrant.pub)"
 
# get virtualbox vid image binary.
[[ -f "./${vdi_name}" ]] || wget "${virtualbox_url}"

# generate meta-date
install -d cidata
echo "local-hostname: localhost.localdomain" >> cidata/meta-data

# generate cloud-init user-data file.
cat << __EOF__ > cidata/user-data
#cloud-config
# vim:syntax=yaml
users:
# A user by the name ec2-user is created in the image by default.
# add vagrant user.
  - default
  - name: vagrant
    groups: wheel
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    plain_text_passwd: vagrant
    ssh-authorized-keys:
      - "${public_key}"
    lock_passwd: false

chpasswd:
  list:
    root:vagrant
  expire: False

# Disable root password reset process at startup by cloud-init
runcmd:
  - sed -i 's/.*root:RANDOM/#&/g' /etc/cloud/cloud.cfg.d/99_onprem.cfg
__EOF__

# generate seed iso images.
[[ -f "./seed.iso" ]] && rm seed.iso
hdiutil makehybrid -iso -joliet -o seed.iso cidata -joliet-volume-name cidata

# CreateVM and Starting for Amazon Linux 2.
vm_name="amznlinux-${release}"
vbox_guest_additions="/Applications/VirtualBox.app/Contents/MacOS/VBoxGuestAdditions.iso"
vbox_version="$(VBoxManage --version)"
VBoxManage createvm --name "${vm_name}" --ostype "RedHat_64" --register
VBoxManage storagectl "${vm_name}" --name "SATA Controller" --add "sata" --controller "IntelAHCI"
VBoxManage storagectl "${vm_name}" --name "IDE Controller" --add "ide"
VBoxManage storageattach "${vm_name}" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "${vdi_name}"
VBoxManage storageattach "${vm_name}" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium seed.iso
VBoxManage storageattach "${vm_name}" --storagectl "IDE Controller" --port 0 --device 1 --type dvddrive --medium "${vbox_guest_additions}"
VBoxManage modifyvm "${vm_name}" --natpf1 "ssh,tcp,127.0.0.1,2222,,22" --memory 4096 --vram 8 --audio none --usb off
VBoxManage startvm "${vm_name}" --type headless

# Download for vagrant insecure private key.
curl -sL https://raw.githubusercontent.com/hashicorp/vagrant/master/keys/vagrant -o vagrant.pem
chmod 600 vagrant.pem

# provisoning for inital configuration.
ssh -o 'StrictHostKeyChecking no' -o 'UserKnownHostsFile=/dev/null' -p 2222 vagrant@127.0.0.1 -i ./vagrant.pem -t <<'EOF'
sudo sed -i -e '/nameserver/d' /etc/resolv.conf
sudo sed -i -e '$a nameserver 1.1.1.1' /etc/resolv.conf
sudo yum -y install kernel-devel kernel-headers dkms gcc gcc-c++
sudo yum -y install make bzip2 perl mod_ssl elfutils-libelf-devel
sudo yum -y update
sudo mount /dev/sr1 /mnt
sudo /mnt/VBoxLinuxAdditions.run
sudo umount /mnt
sudo hostnamectl set-hostname amazonlinux-2
sudo rm -f /etc/udev/rules.d/70-persistent-net.rules
sudo yum clean all
sudo rm -rf /var/cache/yum
sudo find /var/log -type f -exec cp -f /dev/null {} \;
sudo dd if=/dev/zero of=/ZERO bs=1M
sudo rm -f /ZERO
export HISTSIZE=0
sudo shutdown -h now
EOF

# packaging for vagrant box.
VBoxManage controlvm "${vm_name}" poweroff
[[ -f "${vm_name}.box" ]] && rm "${vm_name}.box"
vagrant package --base "${vm_name}" --output "${vm_name}.box"
VBoxManage unregistervm --delete "${vm_name}"
