Vagrant.configure('2') do |config|
  config.vm.box = 'bento/ubuntu-22.04'

  config.vm.provider 'virtualbox' do |vb|
    vb.memory = 2048
    vb.cpus = 2
  end

  config.vm.define 'jenkins-server' do |jenkins|
    jenkins.vm.hostname = 'jenkins-server'
    jenkins.vm.network 'private_network', ip: '192.168.56.10'

    jenkins.vm.provision 'shell', inline: <<-SHELL
      rm -f /etc/apt/sources.list.d/jenkins.list
      rm -f /etc/apt/keyrings/jenkins-keyring.asc
      apt-get update
      apt-get install -y ca-certificates curl fontconfig git gnupg openjdk-21-jre
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key -o /etc/apt/keyrings/jenkins-keyring.asc
      echo deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list
      apt-get update
      apt-get install -y jenkins
      systemctl enable --now jenkins
    SHELL
  end

  config.vm.define 'app-agent' do |agent|
    agent.vm.hostname = 'app-agent'
    agent.vm.network 'private_network', ip: '192.168.56.11'

    agent.vm.provision 'shell', inline: <<-SHELL
      apt-get update
      apt-get install -y ca-certificates curl git gnupg openjdk-21-jre-headless
      install -m 0755 -d /etc/apt/keyrings
      rm -f /etc/apt/keyrings/docker.gpg
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /tmp/docker.asc
      gpg --dearmor --batch --yes --no-tty -o /etc/apt/keyrings/docker.gpg /tmp/docker.asc
      rm -f /tmp/docker.asc
      chmod a+r /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list
      apt-get update
      apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      usermod -aG docker vagrant
      mkdir -p /home/vagrant/jenkins-agent
      chown -R vagrant:vagrant /home/vagrant/jenkins-agent
    SHELL
  end
end
