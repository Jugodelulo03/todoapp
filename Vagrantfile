Vagrant.configure('2') do |config|
  # Imagen base comun para ambas maquinas virtuales.
  config.vm.box = 'bento/ubuntu-22.04'

  config.vm.provider 'virtualbox' do |vb|
    # Recursos minimos para que Jenkins, Docker y MySQL corran con margen.
    vb.memory = 2048
    vb.cpus = 2
  end

  # VM donde vive el servidor Jenkins.
  config.vm.define 'jenkins-server' do |jenkins|
    jenkins.vm.hostname = 'jenkins-server'
    # IP fija para acceder al panel web y para que el agente pueda comunicarse por la red privada.
    jenkins.vm.network 'private_network', ip: '192.168.56.10'

    jenkins.vm.provision 'shell', inline: <<-SHELL
      # Limpia configuraciones viejas del repositorio de Jenkins para que el provisionamiento sea idempotente.
      rm -f /etc/apt/sources.list.d/jenkins.list
      rm -f /etc/apt/keyrings/jenkins-keyring.asc
      apt-get update

      # Instala Java 21 y utilidades basicas que Jenkins necesita para operar.
      apt-get install -y ca-certificates curl fontconfig git gnupg openjdk-21-jre
      install -m 0755 -d /etc/apt/keyrings

      # Registra el repositorio oficial de Jenkins con su llave publica actual.
      curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key -o /etc/apt/keyrings/jenkins-keyring.asc
      echo deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list
      apt-get update

      # Instala Jenkins y lo deja iniciado automaticamente al arrancar la VM.
      apt-get install -y jenkins
      systemctl enable --now jenkins
    SHELL
  end

  # VM que Jenkins usara como agente para correr Docker, builds y despliegues.
  config.vm.define 'app-agent' do |agent|
    agent.vm.hostname = 'app-agent'
    # IP fija para que Jenkins se conecte al agente por SSH sin depender de puertos reenviados.
    agent.vm.network 'private_network', ip: '192.168.56.11'

    agent.vm.provision 'shell', inline: <<-SHELL
      apt-get update

      # Instala Java para el agente SSH de Jenkins y herramientas base de sistema.
      apt-get install -y ca-certificates curl git gnupg openjdk-21-jre-headless
      install -m 0755 -d /etc/apt/keyrings

      # Prepara la llave del repositorio oficial de Docker en formato compatible con apt.
      rm -f /etc/apt/keyrings/docker.gpg
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /tmp/docker.asc
      gpg --dearmor --batch --yes --no-tty -o /etc/apt/keyrings/docker.gpg /tmp/docker.asc
      rm -f /tmp/docker.asc
      chmod a+r /etc/apt/keyrings/docker.gpg

      # Registra el repositorio oficial de Docker segun la arquitectura y version de Ubuntu de la VM.
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list
      apt-get update

      # Instala Docker Engine, Buildx y Docker Compose plugin.
      apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

      # Permite al usuario vagrant usar Docker sin sudo.
      usermod -aG docker vagrant

      # Directorio donde Jenkins dejara su workspace en el agente.
      mkdir -p /home/vagrant/jenkins-agent
      chown -R vagrant:vagrant /home/vagrant/jenkins-agent
    SHELL
  end
end
