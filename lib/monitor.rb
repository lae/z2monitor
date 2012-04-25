#!/usr/bin/ruby

require 'rubygems'
require 'colored'
require 'yaml'
require 'optparse'

require_relative 'api'
require_relative 'misc'

default_profile='localhost'
maintenance=false

OptionParser.new do |o|
  o.banner = "usage: zabbixmon.rb [options]"
  o.on('--profile PROFILE', '-p', "Choose a different Zabbix profile. Current default is #{default_profile}") { |p| $profile = p }
  o.on('--ack MATCH', '-a', "Acknowledge current events that match a pattern MATCH. No wildcards.") { |a| $ackpattern = a.tr('^ A-Za-z0-9[]{},-', '') }
  o.on('--disable-maintenance', '-m', "Filter out servers marked as being in maintenance.") { |m| maintenance = m }
  o.on('-h', 'Show this help') { puts '',o,''; exit }
  o.parse!
end

$profile = default_profile if $profile.nil?
config = YAML::load(open('profiles.yml'))
if config[$profile].nil?
  puts 'Could not load profile '.yellow + '%s'.red % $profile + '! Trying default profile...'.yellow
  $profile = default_profile
  raise StandardError.new('Default profile is missing! Please double check your configuration.'.red) if config[$profile].nil?
end

$monitor = Zabbix::API.new(config[$profile]["url"], config[$profile]["user"], config[$profile]["password"])

def get_events(maint = 1) #TODO: (lines = 0)
  current_time = Time.now.to_i # to be used in getting event durations, but it really depends on the master
  triggers = $monitor.trigger.get_active(2) # Call the API for a list of active triggers
  current_events = []
  triggers.each do |t|
    next if t['hosts'][0]['status'] == '1' or t['items'][0]['status'] == '1' # skip disabled items/hosts that the api call returns
#    break if current_events.length == lines and lines > 0 # don't process any more triggers if we have a limit.
#    event = $monitor.event.get_last_by_trigger(t['triggerid'])
    current_events << {
      :id => t['triggerid'].to_i,
      :time => t['lastchange'].to_i,
      :fuzzytime => fuzz(current_time - t['lastchange'].to_i),
      :severity => t['priority'].to_i,
      :hostname => t['host'],
      :description => t['description'].gsub(/ (on(| server) |to |)#{t['host']}/, '')#,
#      :eventid => event['eventid'].to_i,
#      :acknowledged => event['acknowledged'].to_i
    }
  end
  # Sort the events decreasing by severity, and then descending by duration (smaller timestamps at top)
  return current_events.sort_by { |t| [ -t[:severity], t[:time] ] }
end

if $ackpattern.nil?
  while true
    max_lines = `tput lines`.to_i - 1
    eventlist = get_events #TODO: get_events(max_lines)
    pretty_output = ['%s' % Time.now]
    max_hostlen = eventlist.each.max { |a,b| a[:hostname].length <=> b[:hostname].length }[:hostname].length
    max_desclen = eventlist.each.max { |a,b| a[:description].length <=> b[:description].length }[:description].length
    eventlist.each do |e|
      break if pretty_output.length == max_lines
      ack = "N/A"
      #ack = "Yes" if e[:acknowledged] == 1
      sev_label = case e[:severity]
        when 5; 'Disaster'
        when 4; 'High'
        when 3; 'Warning'
        when 2; 'Average'
        else 'Unknown'
      end
      pretty_output << '[' + '%8s'.color_by_severity(e[:severity]) % sev_label + "] %s\t" % e[:fuzzytime] +
        "%-#{max_hostlen}s\t" % e[:hostname] + "%-#{max_desclen}s".color_by_severity(e[:severity]) % e[:description] +
        "\tAck: %s" % ack
    end
    print "\e[H\e[2J" # clear terminal screen
    puts pretty_output
    sleep(10)
  end
else
  puts 'Retrieving list of active unacknowledged triggers that match: '.bold.blue + '%s'.green % $ackpattern, ''
  filtered = []
  eventlist = get_events()
  eventlist.each do |e|
    if e[:hostname] =~ /#{$ackpattern}/ or e[:description] =~ /#{$ackpattern}/
      event = $monitor.event.get_last_by_trigger(e[:id])
      e[:eventid] = event['eventid'].to_i
      e[:acknowledged] = event['acknowledged'].to_i
      filtered << e if e[:acknowledged] == 0
    end
  end
  abort("No alerts found, so aborting".yellow) if filtered.length == 0
  filtered.each.with_index do |a,i|
    message = '%s - %s (%s)'.color_by_severity(a[:severity]) % [ a[:fuzzytime], a[:description], a[:hostname] ]
    puts "%8d >".bold % (i+1) + message
  end

  print "\n  Select > ".bold
  input = STDIN.gets.chomp()

  no_ack_msg = "Not acknowledging anything."
  raise StandardError.new('No input. #{no_ack_msg}'.green) if input == ''
  to_ack = (1..filtered.length).to_a if input == "all" # only string we'll accept
  raise StandardError.new('Invalid input. #{no_ack_msg}'.red) if to_ack.nil? and (input =~ /^([0-9 ]+)$/).nil?
  to_ack = input.split.map(&:to_i).sort if to_ack.nil? # Split our input into a sorted array of integers
  # Let's first check if a value greater than possible was given, to help prevent typos acknowledging the wrong thing
  to_ack.each { |i| raise StandardError.new('You entered a value greater than %d! Please double check. #{no_ack_msg}'.yellow % filtered.length) if i > filtered.length }

  puts  '', '           Enter an acknowledgement message below, or leave blank for the default.', ''
  print " Message > ".bold
  message = STDIN.gets.chomp()
  puts

  # Finally! Acknowledge EVERYTHING
  to_ack.each do |a|
    puts 'Acknowledging: '.green + '%s (%s)' % [ filtered[a-1][:description], filtered[a-1][:hostname] ]
    if message == ''
      $monitor.event.acknowledge(filtered[a-1][:eventid])
    else
      $monitor.event.acknowledge(filtered[a-1][:eventid], message)
    end
  end
end
