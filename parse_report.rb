#!/usr/bin/env ruby
require 'puppet'
require 'sqlite3'
require 'yaml'

def puppetdb
  db = SQLite3::Database.open "puppet.db"
  db.execute "CREATE TABLE IF NOT EXISTS hosts(id INTEGER PRIMARY KEY, host TEXT)"
  db.execute "CREATE TABLE IF NOT EXISTS resources(id INTEGER PRIMARY KEY, name TEXT, type TEXT)"
  db.execute "CREATE TABLE IF NOT EXISTS host_resources(host_id, resource_id)"
  db
end
def parse_report(db, host, report_path)
  puts "host: #{host}"
  host_id = get_host_id(db, host)
  db.execute('DELETE FROM host_resources WHERE host_id = ?', host_id)

  seen = Set.new
  report_yaml = YAML.load_file(report_path)
  report_yaml.resource_statuses.each_pair do |resource, status|
      status.containment_path.reject{|path| path.start_with?('Packages::') }.each do |path|
        next if path == 'Stage[main]' or seen.include?(path)
        seen.add(path)
        match = path.match(/(?<type>[^\[]+)\[?(?<title>[^\]]+)?\]?$/)
        # We have a defined type
        if match[:title]
          type = match[:type]
          title = match[:title]
        else
          type = 'Class'
          title = match[:type]
        end
        puts "\t#{type}[#{title}]"
        resource_id = get_resource_id(db, title, type)
        db.execute('INSERT INTO host_resources(host_id, resource_id) VALUES(?, ?)', host_id, resource_id)
      end
  end
end

def get_host_id(db, host)
  host_id = db.get_first_value('SELECT id FROM hosts WHERE host = ?', host)
  if host_id
    host_id
  else
    db.execute('INSERT INTO hosts(host) VALUES(?)', host)
    db.last_insert_row_id
  end
end

def get_resource_id(db, title, type)
  resource_id = db.get_first_value('SELECT id FROM resources WHERE name = ? and type = ?', title, type)
  if resource_id
    resource_id
  else
    db.execute('INSERT INTO resources(name, type) VALUES(?, ?)', title, type)
    db.last_insert_row_id
  end
end

def main
  db = puppetdb
  Puppet.initialize_settings
  reports_dir = Puppet['reportdir']
  Dir.each_child(reports_dir) do |host|
    host_dir = File.join(reports_dir, host)
    next unless File.directory?(host_dir) 
    most_recent_report = Dir.glob("#{host_dir}/*.yaml").max_by {|f| File.mtime(f)}
    next unless most_recent_report
    puts "processing: #{most_recent_report}"
    parse_report(db, host, most_recent_report)
  end
end
main
