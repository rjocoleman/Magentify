# =========================================================================
# These are the tasks that are available to help with deploying web apps,
# and specifically, NON Rails applications. You can have cap give you a summary
# of them with `cap -T'.
# =========================================================================

namespace :deploy do
  desc <<-DESC
    Deploys your project. This calls `update'. Note that \
    this will generally only work for applications that have already been deployed \
    once. For a "cold" deploy, you'll want to take a look at the `deploy:cold' \
    task, which handles the cold start specifically.
  DESC
  task :default do
    update
  end

  task :finalize_update, :except => { :no_release => true } do
    # do nothing for non rails apps
  end

  task :restart, :roles => :app, :except => { :no_release => true } do
    # do nothing for non rails apps
  end

  task :migrate, :roles => :db, :only => { :primary => true } do
    # do nothing for non rails apps
  end

  task :migrations do
    set :migrate_target, :latest
    # do nothing for non rails apps
  end

  desc <<-DESC
    Default actions only calls 'update'.
  DESC
  task :cold do
    update
  end

  namespace :web do
    task :disable, :roles => :web, :except => { :no_release => true } do
      # do nothing for non rails apps
    end
          
    task :enable, :roles => :web, :except => { :no_release => true } do
      # do nothing for non rails apps
    end
  end
end