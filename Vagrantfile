VAGRANTFILE_API_VERSION = "2"
require 'yaml'
require_relative 'vagrant_scripts/git_commands'


# default variables these can be overritten in dev-env-project/vm_config
@RAM = 1024
# end of default variables

TRY_APPS = true
DEV_ENV_CONTEXT_FILE = File.dirname(__FILE__) + "/.dev-env-context"

if ['up', 'resume', 'reload'].include? ARGV[0]
  #check for context file if not found create one
  if not File.exists?(DEV_ENV_CONTEXT_FILE)
    puts("Please enter the url of your project configuration repo: ")
    project_configuration_url = STDIN.gets.chomp
    File.open(DEV_ENV_CONTEXT_FILE, "w+") { |file| file.write(project_configuration_url) }
  end

  # update dev-env-project
  puts("Retrieving configuration repo:")
  command_successful = update_or_pull(File.dirname(__FILE__) + '/dev-env-project', File.read(DEV_ENV_CONTEXT_FILE))

  # if updating configuration failed ask the user if they want to continue and if they want to update apps
  if not command_successful
    puts("Something went wrong getting the configuration repo")
    print("do you want to continue anyway? Y/N")
    temp = STDIN.gets.chomp
    if temp == 'y' or temp =='Y' or temp == 'YES' or temp == 'Y'
      print("do you want to try to pull down the app repos? Y/N")
      temp = STDIN.gets.chomp
      if temp == 'y' or temp =='Y' or temp == 'YES' or temp == 'Y'
        TRY_APPS = true
      else
        TRY_APPS = false
      end
    else
      exit 1
    end
  end

  app_config = YAML.load_file("#{File.dirname(__FILE__)}/dev-env-project/configuration.yml")
  #update users apps unless the user has specifed not to
  if TRY_APPS
    puts("Updating apps:")
    if app_config["applications"]
      app_config["applications"].each do |appname, appconfig|
        command_successful = update_or_pull("#{File.dirname(__FILE__)}/apps/#{appname}", appconfig["repo"], appconfig['branch'])
        #if app fails to download then error
        if not command_successful
          puts("Something went wrong updating #{appname}")
          exit 1
        end
      end
    end

    puts("Updating commodities:")
    if app_config["commodities"]
      app_config["commodities"].each do |commodityname, commodityconfig|
        command_successful = update_or_pull("#{File.dirname(__FILE__)}/commodities/#{commodityname}", commodityconfig["repo"], commodityconfig['branch'])
        #if commodity fails to download then error
        if not command_successful
          puts("Something went wrong updating #{commodityname}")
          exit 1
        end
      end
    end
  else
    print("you have chosen not to pull down the apps so we will continue")
  end
end

if File.exists?(File.dirname(__FILE__) + '/dev-env-project/vm_config.rb')
  require_relative 'dev-env-project/vm_config'
end

Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu/trusty64"

  config.vm.provider "virtualbox" do |v|
    v.memory = @RAM
  end

  # Only if vagrant up/resume do we want to forward ports
  if ['up', 'resume', 'reload'].include? ARGV[0]
    if File.exists?(File.dirname(__FILE__) + '/dev-env-project/forward_ports.rb')
      require_relative 'dev-env-project/forward_ports'
      forward_ports(config)
    else
      print("you have not specified any ports to forward")
    end
  end

  config.vm.provision :docker

  if File.exists?(File.dirname(__FILE__) + '/dev-env-project/db_setup.sh')
    #create persistent database storage
    config.vm.provision "shell", inline: "docker volume create --name=database-data"
  end

  config.vm.provision :docker_compose, yml: "/vagrant/dev-env-project/docker-compose.yml", rebuild: true, run: "always"

  #allows you to run docker-compose commands from anywhere
  config.vm.provision "shell", inline: "echo \"export COMPOSE_FILE='/vagrant/dev-env-project/docker-compose.yml'\" >> /home/vagrant/.bash_profile"

  #setup database if we have one
  if File.exists?(File.dirname(__FILE__) + '/dev-env-project/db_setup.sh')
    config.vm.provision "shell", path: "dev-env-project/db_setup.sh"
  else
    print("you have not specified any databases to set up")
  end

end
