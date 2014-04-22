# -*- mode: ruby -*-
# vi: set ft=ruby :

nodes = {
  'controller' => [1, 200],
}

Vagrant.configure("2") do |config|
  config.vm.box = "precise64"
  config.vm.box_url =
    "http://files.vagrantup.com/precise64.box"

  # Forescout NAC workaround
  config.vm.usable_port_range = 2800..2900

  nodes.each do |prefix, (count, ip_start)|
    count.times do |i|
      hostname = "%s" % [prefix, (i+1)]

      config.vm.define "#{hostname}" do |box|
        box.vm.hostname = "#{hostname}.book"
        box.vm.network :private_network, ip:
          "172.16.0.#{ip_start+i}", :netmask =>
            "255.255.0.0"
        box.vm.network :private_network, ip:
          "10.10.0.#{ip_start+i}", :netmask =>
            "255.255.0.0"
        box.vm.network :private_network, ip:
          "192.168.100.#{ip_start+i}", :netmask =>
            "255.255.255.0"
            
        # Otherwise using VirtualBox
        box.vm.provider :virtualbox do |vbox|
          # Defaults
          vbox.customize ["modifyvm", :id, "--memory",
            2048]
          vbox.customize ["modifyvm", :id, "--cpus", 1]
        end
      end
    end
  end
end

