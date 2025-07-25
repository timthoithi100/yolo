Vagrant.configure("2") do |config|
  config.vm.define "ansible-target" do |ansible_target|
    ansible_target.vm.box = "geerlingguy/ubuntu2004"
    ansible_target.vm.hostname = "ansible-target"
    ansible_target.vm.network "private_network", ip: "192.168.56.10"
    ansible_target.vm.network "forwarded_port", guest: 3000, host: 3001, auto_correct: true 
    ansible_target.vm.network "forwarded_port", guest: 5000, host: 5000, auto_correct: true
    ansible_target.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = 2
      vb.name = "YOLO-Ansible-VM"
    end
  end
end
