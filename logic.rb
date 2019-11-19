# -*- mode: ruby -*-
# vi: set ft=ruby :

# This file contains various functions that call be called as the command line argument.
#
# Before running any command below that makes calls to Docker Compose,
# the command prepare-docker-environment should be run
# followed by sourcing scripts/prepare-docker.sh so that the correct
# apps are loaded into the Docker Compose environment variable. Just in
# case people have multiple copies of this dev-env using different configs.

require_relative 'scripts/utilities'
require_relative 'scripts/update_apps'

require 'fileutils'
require 'open3'
require 'highline/import'
require 'rubygems'

# Ensures stdout is never buffered
STDOUT.sync = true

# Where is this file located? (From Ruby's perspective)
root_loc = __dir__

# Define the DEV_ENV_CONTEXT_FILE file name to store the users app_grouping choice
# As vagrant up can be run from any subdirectory, we must make sure it is stored alongside the Vagrantfile
DEV_ENV_CONTEXT_FILE = root_loc + '/.dev-env-context'

# Where we clone the dev env configuration repo into
DEV_ENV_CONFIG_DIR = root_loc + '/dev-env-project'

# A list of all the docker compose fragments we find, so they can be loaded into an env var and used as one big file
DOCKER_COMPOSE_FILE_LIST = root_loc + '/dev-env-project/docker-compose.yml'

if ARGV.length != 1
  puts colorize_red('We need exactly one argument')
  exit 1
end

if ['stop'].include? ARGV[0]
  if File.exist?(DOCKER_COMPOSE_FILE_LIST) && File.size(DOCKER_COMPOSE_FILE_LIST) != 0
    # If this file exists it must have previously got to the point of creating the containers
    # and if it has something in we know there are apps to stop and won't get an error
    puts colorize_lightblue('Stopping apps:')
    run_command('docker-compose stop')
  end
end

# Ask for/update the dev-env configuration.
# Then use that config to clone/update apps, create commodities and custom provision lists
# and download supporting files
if ['prep'].include?(ARGV[0])
  # Check if a DEV_ENV_CONTEXT_FILE exists, to prevent prompting for dev-env configuration choice on each vagrant up
  if File.exist?(DEV_ENV_CONTEXT_FILE)
    puts ''
    puts colorize_green("This dev env has been provisioned to run for the repo: #{File.read(DEV_ENV_CONTEXT_FILE)}")
  else
    print colorize_yellow('Please enter the (Git) url of your dev env configuration repository: ')
    app_grouping = STDIN.gets.chomp
    File.open(DEV_ENV_CONTEXT_FILE, 'w+') { |file| file.write(app_grouping) }
  end

  # Check if dev-env-config exists, and if so pull the dev-env configuration. Otherwise clone it.
  puts colorize_lightblue('Retrieving custom configuration repo files:')
  if Dir.exist?(DEV_ENV_CONFIG_DIR)
    command_successful = run_command("git -C #{root_loc}/dev-env-project pull")
    new_project = false
  else
    command_successful = run_command("git clone #{File.read(DEV_ENV_CONTEXT_FILE)} #{root_loc}/dev-env-project")
    new_project = true
  end

  # Error if git clone or pulling failed
  fail_and_exit(new_project) if command_successful != 0

  # Call the ruby function to pull/clone all the apps found in dev-env-config/configuration.yml
  puts colorize_lightblue('Updating apps:')
  update_apps(root_loc)

end

if ['reset'].include?(ARGV[0])
  # remove DEV_ENV_CONTEXT_FILE created on provisioning
  confirm = nil
  until %w[Y y N n].include?(confirm)
    confirm = ask colorize_yellow('Would you like to KEEP your dev-env configuration files? (y/n) ')
  end
  if confirm.upcase.start_with?('N')
    File.delete(DEV_ENV_CONTEXT_FILE) if File.exist?(DEV_ENV_CONTEXT_FILE)
    FileUtils.rm_r DEV_ENV_CONFIG_DIR if Dir.exist?(DEV_ENV_CONFIG_DIR)
  end
  # remove files created on provisioning
  File.delete(CUSTOM_PROVISION_FILE) if File.exist?(CUSTOM_PROVISION_FILE)
  File.delete(AFTER_UP_ONCE_FILE) if File.exist?(AFTER_UP_ONCE_FILE)

  # Docker
  run_command('docker-compose down --rmi all --volumes --remove-orphans')

  puts colorize_green('Environment reset')
end

# Run script to configure environment
# TODO bash autocompletion of container names
if ['prepare-compose-environment'].include?(ARGV[0])
  # Call the ruby function to create the docker compose file containing the apps and their commodities
  puts colorize_lightblue('Creating docker-compose file list')
  prepare_compose(root_loc, DOCKER_COMPOSE_FILE_LIST)
end

if ['start'].include?(ARGV[0])
  if File.size(DOCKER_COMPOSE_FILE_LIST).zero?
    puts colorize_red('Nothing to start!')
    exit
  end

  puts colorize_lightblue('Building images...')
  if run_command('docker-compose build --parallel') != 0
    puts colorize_yellow('Build command failed. Trying without --parallel')
    # Might not be running a version of compose that supports --parallel, try one more time
    if run_command('docker-compose build') != 0
      puts colorize_red('Something went wrong when creating your app images or containers. Check the output above.')
      exit
    end
  end

  # Now that commodities are all provisioned, we can start the containers
  puts colorize_lightblue('Starting containers...')
  up_exit_code = run_command('docker-compose up --remove-orphans -d --force-recreate')
  if up_exit_code != 0
    puts colorize_red('Something went wrong when creating your app images or containers. Check the output above.')
    exit
  end

  puts colorize_green('All done, environment is ready for use')
end
