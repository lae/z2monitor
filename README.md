# z2monitor

A command line interface for viewing alerts from a Zabbix instance. (Zabbix API 2.0)

## Requirements
Rubygems: json (json_pure is fine), colored

## Usage
    z2monitor [options]
        -a, --ack MATCH                  Acknowledge current events that match a pattern MATCH. No wildcards.
        -m, --disable-maintenance        Filter out servers marked as being in maintenance.
        -1, --print-once                 Only check Zabbix once and print out all alerts.
        -h                               Show this help

## Setting Up

Install the gem:

    gem install z2monitor

And run:

    z2monitor

You'll be prompted initially for the server, and your login information. If you make a mistake or ned to use something
different, just remove the associated files in your home directory:

    rm ~/.zmonitor-token ~/.zmonitor-server

## TODO
* Fixup weird debugging / add verbose flag.
* Move the output into an ncurses layout
