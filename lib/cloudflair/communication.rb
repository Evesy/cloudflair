require 'cloudflair/error/cloudflare_error'
require 'cloudflair/error/cloudflair_error'
require 'cloudflair/connection'

module Cloudflair
  module Communication
    def response(response)
      return nil if response.status == 304

      raise_on_http_error response.status

      read response
    end

    def connection
      Cloudflair::Connection.new
    end

    def hash_to_object(hash)
      objectified_class = Class.new
      objectified_instance = objectified_class.new
      hash.each do |k, v|
        variable_name = sanitize_variable_name(k)
        variable_name = "_#{variable_name}" if objectified_instance.methods.map(&:to_s).include?(variable_name)

        objectified_instance.instance_variable_set("@#{variable_name}", v)
        objectified_class.send :define_method, variable_name, proc { instance_variable_get("@#{variable_name}") }
      end
      objectified_instance
    end

    private

    def read(response)
      body = response.body

      unless body['success']
        fail Cloudflair::CloudflairError, "Unrecognized response format: '#{body}'" unless body['errors']
        fail Cloudflair::CloudflareError, body['errors']
      end

      body['result']
    end

    def raise_on_http_error(status)
      case status
      when 200..399 then
      when 400..499 then
        raise_on_http_client_error status
      when 500..599 then
        fail Cloudflair::CloudflairError, "#{status} Remote Error"
      else
        fail Cloudflair::CloudflairError, "#{status} Unknown Error Code"
      end
    end

    def raise_on_http_client_error(status)
      case status
      when 400 then
        fail Cloudflair::CloudflairError, '400 Bad Request'
      when 401 then
        fail Cloudflair::CloudflairError, '401 Unauthorized'
      when 403 then
        fail Cloudflair::CloudflairError, '403 Forbidden'
      when 405 then
        fail Cloudflair::CloudflairError, '405 Method Not Allowed'
      when 415 then
        fail Cloudflair::CloudflairError, '415 Unsupported Media Type'
      when 429 then
        fail Cloudflair::CloudflairError, '429 Too Many Requests'
      else
        fail Cloudflair::CloudflairError, "#{status} Request Error"
      end
    end

    def sanitize_variable_name(raw_name)
      raw_name.gsub(/[^a-zA-Z0-9_]/, '_')
    end
  end
end
