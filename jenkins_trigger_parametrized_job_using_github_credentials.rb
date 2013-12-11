#!/usr/bin/env ruby

require 'fileutils'

begin
  gem 'mechanize'
  gem 'colorize'
rescue Gem::LoadError => e
  puts "ERROR Some gems where not found."
  puts "error was: #{e}"
  exit
ensure
  require 'mechanize'
  require 'colorize'
end

puppet_dir = '/etc/puppet'
jenkins_login_url = 'http://jenkins/securityRealm/commenceLogin'
jenkins_job_url = 'http://jenkins/job/parametrized_job'
github_user = 'test'
github_pass = 'test'

if not File.exists? puppet_dir
  $stderr.puts "#{0} error: puppet dir #{puppet_dir} not exists"
  exit 1
end

# Login into github
print "logging into github "
a = Mechanize.new 
a.user_agent_alias = 'Mac Safari'
page = a.get 'https://github.com/login' do |github|
  github.forms[1]['login'] = github_user
  github.forms[1]['password'] = github_pass
  github.forms[1].submit
end

if a.get('https://github.com').content.match(/#{github_user}/)
  puts "OK".green
else
  puts "FAILED".red
  exit
end

# Login into jenkins using github cookies
print "logging into jenkins "
a.get jenkins_login_url
if a.get(jenkins_login_url).content.match(/#{github_user}/)
  puts "OK".green
else
  puts "FAILED".red
  exit
end

#Create the zip file
print "Create zip file "
Dir.chdir puppet_dir
%x[zip -pr puppet.zip *]
puts "OK".green

# Post the zip file
print "Uploading zip file into jenkins "
page = nil
begin
  file = File.open('puppet.zip','r')
  page = a.post(
    jenkins_job_url + '/build?delay=0sec',
    {
    "name" => "branch.zip",
    "file0" => file,
    "statusCode" => "303",
    "redirectTo" => '.',
    "json" => '{"parameter": {"name": "branch.zip", "file": "file0"}, "statusCode": "303", "redirectTo": "."}',
    "Submit" => "Build",
    }
  )
  file.close
rescue => e
  puts e
end
puts "OK".green

build_number = page.link_with(:text => /Last build/).text.scan(/[0-9]+/).first.to_i

print "Job exit code "
status = nil
while status == nil

  status = a.post(
    jenkins_job_url + '/buildHistory/ajax',
    {},
    { 
    'n' => build_number
  }
  ).content.match(/Success|Failed/)

end

stat = status[0] == "Success" ? "OK".green : "Failed".red

puts stat

# Remove the zip file:
FileUtils.rm 'puppet.zip'
