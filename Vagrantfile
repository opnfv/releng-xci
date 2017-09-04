# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Verify whether required plugins are installed.
required_plugins = [ "vagrant-disksize" ]
required_plugins.each do |plugin|
  if not Vagrant.has_plugin?(plugin)
    raise "The vagrant plugin #{plugin} is required. Please run `vagrant plugin install #{plugin}`"
  end
end

Vagrant.configure(2) do |config|

  # Configure all VM specs.
  config.vm.provider "virtualbox" do |v|
    v.memory = 16384
    v.cpus = 8
  end

  # Configure the disk size.
  disk_size = "160GB"

  # The below options are good enough for the 'mini' flavor but
  # make sure you export the variables to match the flavor you want to test.
  config.vm.define "ubuntu1604" do |xenial|
    xenial.vm.box = "ubuntu/xenial64"
    xenial.disksize.size = disk_size
    config.vm.provision "shell"do |s|
      s.privileged = false
      s.inline = <<-SHELL
          cd /vagrant
          export XCI_FLAVOR=${XCI_FLAVOR:-mini}
          export VM_CPU=${VM_CPU:-2}
          export VM_DISK=${VM_DISK:-40}
          export VM_MEMORY_SIZE=${VM_MEMORY_SIZE:-2048}
          export VM_DOMAIN_TYPE=qemu
          export PATH=$PATH:$HOME/.local/bin
          export OPNFV_RELENG_DEV_PATH=/vagrant
          [[ ! -e ${HOME}/.ssh/id_rsa ]] && ssh-keygen -q -P '' -f ${HOME}/.ssh/id_rsa
          cd xci && ./xci-deploy.sh
      SHELL
      s.env = {
          "XCI_FLAVOR" => "#{ENV['XCI_FLAVOR']}",
          "VM_CPU" => "#{ENV['VM_CPU']}",
          "VM_DISK" => "#{ENV['VM_DISK']}",
          "VM_MEMORY_SIZE" => "#{ENV['VM_MEMORY_SIZE']}"
      }
    end
  end

  config.vm.define "centos7" do |centos7|
    centos7.vm.box = "centos/7"
    centos7.disksize.size = disk_size
    # The CentOS build does not have growroot, so we
    # have to do it ourselves.
    config.vm.provision "shell" do |s|
      s.privileged = false
      s.inline = <<-SHELL
          cd /vagrant
          PART_START=$(sudo parted /dev/sda --script unit MB print | awk '/^ 3 / {print $3}')
          sudo parted /dev/sda --script unit MB mkpart primary ${PART_START} 100%
          sudo parted /dev/sda --script set 4 lvm on
          sudo pvcreate /dev/sda4
          sudo vgextend VolGroup00 /dev/sda4
          sudo lvextend -l +100%FREE /dev/mapper/VolGroup00-LogVol00
          sudo xfs_growfs /dev/mapper/VolGroup00-LogVol00
          export XCI_FLAVOR=${XCI_FLAVOR:-mini}
          export VM_CPU=${VM_CPU:-2}
          export VM_DISK=${VM_DISK:-40}
          export VM_MEMORY_SIZE=${VM_MEMORY_SIZE:-2048}
          export VM_DOMAIN_TYPE=qemu
          export PATH=$PATH:$HOME/.local/bin
          export OPNFV_RELENG_DEV_PATH=/vagrant
          [[ ! -e ${HOME}/.ssh/id_rsa ]] && ssh-keygen -q -P '' -f ${HOME}/.ssh/id_rsa
          cd xci && ./xci-deploy.sh
      SHELL
      s.env = {
          "XCI_FLAVOR" => "#{ENV['XCI_FLAVOR']}",
          "VM_CPU" => "#{ENV['VM_CPU']}",
          "VM_DISK" => "#{ENV['VM_DISK']}",
          "VM_MEMORY_SIZE" => "#{ENV['VM_MEMORY_SIZE']}"
      }
    end
  end

  config.vm.define "opensuse422" do |leap422|
    leap422.disksize.size = disk_size
    leap422.vm.box = "opensuse/openSUSE-42.2-x86_64"
    leap422.vm.provision "shell" do |s|
      # NOTE(hwoarang) The parted version in Leap 42.2 can't do an online
      # partition resize so we must create a new one and attach it to the
      # btrfs filesystem.
      s.privileged = false
      s.inline = <<-SHELL
        cd /vagrant
        echo -e 'd\n2\nn\np\n\n\n\nn\nw' | sudo fdisk /dev/sda
        PART_END=$(sudo fdisk -l /dev/sda | grep ^/dev/sda2 | awk '{print $4}')
        sudo resizepart /dev/sda 2 $PART_END
        sudo btrfs fi resize max /
        export XCI_FLAVOR=${XCI_FLAVOR:-mini}
        export VM_CPU=${VM_CPU:-2}
        export VM_DISK=${VM_DISK:-40}
        export VM_MEMORY_SIZE=${VM_MEMORY_SIZE:-2048}
        export VM_DOMAIN_TYPE=qemu
        export PATH=$PATH:$HOME/.local/bin
        export OPNFV_RELENG_DEV_PATH=/vagrant
        [[ ! -e ${HOME}/.ssh/id_rsa ]] && ssh-keygen -q -P '' -f ${HOME}/.ssh/id_rsa
        cd xci && ./xci-deploy.sh
      SHELL
    end
  end

  config.vm.define "opensuse423" do |leap423|
    leap423.disksize.size = disk_size
    leap423.vm.box = "opensuse/openSUSE-42.3-x86_64"
    leap423.vm.provision "shell" do |s|
      # NOTE(hwoarang) The parted version in Leap 42.3 can't do an online
      # partition resize so we must create a new one and attach it to the
      # btrfs filesystem.
      s.privileged = false
      s.inline = <<-SHELL
        cd /vagrant
        echo -e 'd\n2\nn\np\n\n\n\nn\nw' | sudo fdisk /dev/sda
        PART_END=$(sudo fdisk -l /dev/sda | grep ^/dev/sda2 | awk '{print $4}')
        sudo resizepart /dev/sda 2 $PART_END
        sudo btrfs fi resize max /
        export XCI_FLAVOR=${XCI_FLAVOR:-mini}
        export VM_CPU=${VM_CPU:-2}
        export VM_DISK=${VM_DISK:-40}
        export VM_MEMORY_SIZE=${VM_MEMORY_SIZE:-2048}
        export VM_DOMAIN_TYPE=qemu
        export PATH=$PATH:$HOME/.local/bin
        export OPNFV_RELENG_DEV_PATH=/vagrant
        # workaround for https://github.com/openSUSE/vagrant/pull/22
        sudo bash -c 'echo "127.0.0.1 localhost" >> /etc/hosts'
        [[ ! -e ${HOME}/.ssh/id_rsa ]] && ssh-keygen -q -P '' -f ${HOME}/.ssh/id_rsa
        cd xci && ./xci-deploy.sh
      SHELL
    end
  end
end
