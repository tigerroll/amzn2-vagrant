# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.require_version ">= 1.6.2"

BOX_NAME = "amazonlinux2-x86_64"

Vagrant.configure("2") do |config|

  config.vm.box = BOX_NAME
  config.vm.box_url = Dir.glob("amznlinux*.box")
  config.vm.box_check_update = true
  config.vm.hostname = "amazonlinux2-vagrant"
  config.vm.network :private_network, ip: "192.168.33.10" 
  config.vm.network :forwarded_port, guest: 80, host: 8080
  config.ssh.forward_x11 = true

  config.vm.provider :virtualbox do |vb|
     vb.gui = false
     vb.name = BOX_NAME
     vb.customize ["modifyvm", :id, "--memory", "4096"]
     vb.customize ["modifyvm", :id, "--cpus", "2"]
     vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
     vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
  end

  # Shared directory
  config.vm.synced_folder ".", "/vagrant", type: "virtualbox", :mount_options => ['dmode=777', 'fmode=777']

end
