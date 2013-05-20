load Gem.find_files('nonrails.rb').last.to_s


require 'magnetize'
require 'dotenv'

# =========================================================================
# These variables MUST be set in the client capfiles. If they are not set,
# the deploy will fail with an error.
# =========================================================================
_cset(:admin_symlinks) {
  abort "Please specify an array of symlinks to shared resources, set :admin_symlinks, ['/media', ./. '/staging']"
}
_cset(:admin_shared_dirs)  {
  abort "Please specify an array of shared directories to be created, set :admin_shared_dirs"
}
_cset(:admin_shared_files)  {
  abort "Please specify an array of shared files to be symlinked, set :admin_shared_files"
}

_cset(:deploy_config) {
  abort "Please specify the .env config to be deployed, set :deploy_config"
}

def magerun_defaults
  "--no-ansi --no-interaction --root-dir=#{current_path}"
end

def magerun
  "$HOME/bin/n98-magerun.phar #{magerun_defaults}"
end

namespace :mage do
 desc <<-DESC
    Prepares one or more servers for deployment of Magento. Before you can use any \
    of the Capistrano deployment tasks with your project, you will need to \
    make sure all of your servers have been prepared with `cap deploy:setup'. When \
    you add a new server to your cluster, you can easily run the setup task \
    on just that server by specifying the HOSTS environment variable:

      $ cap HOSTS=new.server.com mage:deploy_setup

    It is safe to run this task on servers that have already been set up; it \
    will not destroy any deployed revisions or data.
  DESC
  task :deploy_setup, :roles => [:web, :admin], :except => { :no_release => true } do
    if app_shared_dirs
      app_shared_dirs.each { |link| run "#{try_sudo} mkdir -p #{shared_path}#{link} && #{try_sudo} chmod g+w #{shared_path}#{link}"}
    end
    if app_shared_files
      app_shared_files.each { |link| run "#{try_sudo} touch #{shared_path}#{link} && #{try_sudo} chmod g+w #{shared_path}#{link}" }
    end
  end

  task :auto_configure do
    Dotenv.load ".env.#{deploy_config}"
    magento = Magnetize::Magento.new
    put magento.to_xml("app/etc/local.xml"), "#{latest_release}/app/etc/local.xml"
    put magento.to_xml("errors/local.xml"), "#{latest_release}/errors/local.xml"
  end

  desc "Magento: Deploy app/etc/local.xml and errors/local.xml"
  task :configure do
    Capistrano::CLI.ui.say "<%= color '*'*70, :red %>"
    if Capistrano::CLI.ui.agree "<%= color 'You are about to push your .env.#{deploy_config}. Continue? (y/N)', :yellow %>"
      Capistrano::CLI.ui.say "<%= color '*** Deploying config', :green %>"
      auto_configure
    else
      Capistrano::CLI.ui.say "<%= color '*** Config deploy ABORTED.', :red %>"
    end
  end
  
  desc "Magento: Install n98-magerun.phar"
  task :install_magerun, :roles => [:admin, :web], :except => { :no_release => true } do
    # this is noisy, it's just cosmetic though.
    run "mkdir -p $HOME/bin"
    run "curl -o $HOME/bin/n98-magerun.phar https://raw.github.com/netz98/n98-magerun/master/n98-magerun.phar"
    run "chmod +x $HOME/bin/n98-magerun.phar"
  end

  # Touches up the released code. This is called by update_code after the basic deploy finishes.
  # Any directories deployed from the SCM are first removed and then replaced with symlinks to the same directories within the shared location.
  task :finalize_update, :roles => [:web, :admin], :except => { :no_release => true } do    
    run "chmod -R g+w #{latest_release}" if fetch(:group_writable, true)

    if app_symlinks
      # Remove the contents of the shared directories if they were deployed from SCM
      app_symlinks.each { |link| run "#{try_sudo} rm -rf #{latest_release}#{link}" }
      # Add symlinks the directoris in the shared location
      app_symlinks.each { |link| run "ln -nfs #{shared_path}#{link} #{latest_release}#{link}" }
    end

    if app_shared_files
      # Remove the contents of the shared directories if they were deployed from SCM
      app_shared_files.each { |link| run "#{try_sudo} rm -rf #{latest_release}/#{link}" }
      # Add symlinks the directories in the shared location
      app_shared_files.each { |link| run "ln -s #{shared_path}#{link} #{latest_release}#{link}" }
    end
  end
  
  desc "Magento: Run module setup scripts"
  task :setup_scripts, :roles => :admin do
    run "#{magerun} sys:setup:run"
  end

  desc "Magento: Cache Flush"
  task :cacheflush, :roles => [:web, :admin] do
    run "#{magerun} cache:flush"
  end

  desc "Magento: Enable Maintenance mode (default: web nodes)"
  task :maintain, :roles => :web do
    run "#{magerun} sys:maintenance --on"
  end

  desc "Magento: Disable Maintenance mode (default: web nodes)"
  task :maintainoff, :roles => :web do
    run "#{magerun} sys:maintenance --off"
  end

  desc "Magento: Indexer reindex all"
  task :reindexall, :roles => :admin do
    run "#{magerun} index:reindex:all"
  end

  desc "Magento: n98-magerun interactive shell"
  task :shell, :roles => :admin do
    hostname = find_servers_for_task(current_task).first
    exec "ssh -l #{user} #{hostname} -t 'source ~/.profile && #{magerun} shell'"
  end
  
  desc "Magento: Disable Cron (flag)"
  task :cronoff, :roles => :admin do
    run "touch #{current_path}/disablecron.flag"
  end
  
  desc "Magento: Enable cron (flag)"
  task :cronon, :roles => :admin do
    run "rm #{current_path}/disablecron.flag"
  end
end

# setup run only
after 'deploy:setup', 'mage:deploy_setup', 'mage:install_magerun'

#every deploy
before 'deploy', 'mage:maintain'
after 'deploy:finalize_update', 'mage:finalize_update', 'mage:auto_configure'
after 'deploy:create_symlink', 'mage:cacheflush', 'mage:setup_scripts', 'mage:maintainoff', 'deploy:cleanup'
