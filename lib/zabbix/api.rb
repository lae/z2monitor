#!/usr/bin/ruby

require 'rubygems'
require 'json'
require 'net/http'
require 'net/https'

# create the module/class stub so we can require the API class files properly
module Zabbix
  class API
  end
end

# load up the different API functions
require_relative 'api/event'
require_relative 'api/trigger'
require_relative 'api/user'

module Zabbix
  class API
    attr_accessor :server, :verbose, :authtoken

    attr_accessor :event, :trigger, :user # API classes

    def initialize( server = "http://localhost", verbose = false )
      # Parse the URL beforehand
      @server = URI.parse(server)
      @verbose = verbose
      @event = Zabbix::Event.new(self)
      @trigger = Zabbix::Trigger.new(self)
      @user = Zabbix::User.new(self)
    end

    # More specific error names, may add extra handling procedures later
    class ResponseCodeError < StandardError
    end
    class ResponseError < StandardError
    end
    class NotAuthorisedError < StandardError
    end

    def call_api(message)
      # Finish preparing the JSON call
      message['id'] = rand 100000 if message['id'].nil?
      message['jsonrpc'] = '2.0'
      # Check if we have authorization token
      if @authtoken.nil? && message['method'] != 'user.login'
        raise NotAuthorisedError.new("[ERROR] Authorisation Token not initialised. message => #{message}")
      else
        message['auth'] = @authtoken if message['method'] != 'user.login'
      end

      json_message = JSON.generate(message)

      # Open TCP connection to Zabbix master
      connection = Net::HTTP.new(@server.host, @server.port)
      # Check to see if we're connecting via SSL
      if @server.scheme == 'https' then
        connection.use_ssl = true
        connection.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      # Prepare POST request for sending
      request = Net::HTTP::Post.new(@server.request_uri)
      request.add_field('Content-Type', 'application/json-rpc')
      request.body = json_message

      # Send request
      begin
        puts "[INFO] Attempting to send request => #{request}" if @verbose
        response = connection.request(request)
      rescue ::SocketError => e
        puts "[ERROR] Could not complete request: SocketError => #{e.message}" if @verbose
        raise SocketError.new(e.message)
      end

      puts "[INFO] Received response: #{response}" if @verbose
      raise ResponseCodeError.new("[ERROR] Did not receive 200 OK, but HTTP code #{response.code}") if response.code != "200"

      parsed_response = JSON.parse(response.body)
      if error = parsed_response['error']
        raise ResponseError.new("[ERROR] Received error response: code => #{error['code'].to_s}; message => #{error['message']}; data => #{error['data']}")
      end

      return parsed_response['result']
    end

  end
end
