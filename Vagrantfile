# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
    config.vm.define "testing"
    config.vm.box = "ubuntu/xenial64"
    config.vm.network "private_network", type: "dhcp"

    config.vm.provision :ansible do |ansible|
        ansible.playbook = "deploy.yml"
        ansible.inventory_path = "hosts"
    end
end
