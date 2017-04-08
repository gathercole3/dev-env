#!/usr/bin/env ruby
def pull_from_git(repo, clone_location, required_branch='master')
  system 'git', 'clone', repo, clone_location

  current_branch = `git -C #{clone_location} rev-parse --abbrev-ref HEAD`.strip
  if not current_branch.eql? required_branch
    system 'git', '-C', "#{clone_location}", 'checkout', '--track', "origin/#{required_branch}"
  else
    true
  end
end

def update_from_repo(location)
  system 'git', '-C', "#{location}", 'fetch', 'origin'
end

def update_or_pull(file_location, repo, required_branch='master')
  if Dir.exists?("#{file_location}")
    current_branch = `git -C #{file_location} rev-parse --abbrev-ref HEAD`.strip
    if not current_branch.eql? required_branch
      puts("current branch #{current_branch} is different to required branch #{required_branch} so we will not update")
      return true
    end
    # Update all the remote branches (this will not change the local branch, we'll do that further down')
    if not update_from_repo("#{file_location}")
      return false
    end

  else
    if not pull_from_git(repo, "#{file_location}", required_branch)
      return false
    end
  end
  return true
end
