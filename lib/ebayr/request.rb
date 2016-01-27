# -*- encoding : utf-8 -*-
module Ebayr #:nodoc:
  # Encapsulates a request which is sent to the eBay Trading API.
  class Request

    attr_reader :command

    # Make a new call. The URI used will be that of Ebayr::uri, unless
    # overridden here (same for auth_token, site_id and compatability_level).
    def initialize(configuration, command, options = {})
      @configuration = configuration
      @command = camelize(command.to_s)
      @uri = options.delete(:uri) || self.uri
      @uri = URI.parse(@uri) unless @uri.is_a? URI
      @auth_token = (options.delete(:auth_token) || self.auth_token).to_s
      @site_id = (options.delete(:site_id) || self.site_id).to_s
      @compatability_level = (options.delete(:compatability_level) || self.compatability_level).to_s
      @http_timeout = (options.delete(:http_timeout) || 60).to_i
      # Remaining options are converted and used as input to the call
      @input = options.delete(:input) || options
      @attachment = options.delete(:attachment)
    end

    def method_missing(method, *args, &block)
      if @configuration.respond_to?(method)
        @configuration.send method, *args, &block
      else
        super
      end
    end

    # Gets the path to which this request will be posted
    def path
      @uri.path
    end

    # Gets the headers that will be sent with this request.
    def headers
      {
        'X-EBAY-API-COMPATIBILITY-LEVEL' => @compatability_level.to_s,
        'X-EBAY-API-DEV-NAME' => dev_id.to_s,
        'X-EBAY-API-APP-NAME' => app_id.to_s,
        'X-EBAY-API-CERT-NAME' => cert_id.to_s,
        'X-EBAY-API-CALL-NAME' => @command.to_s,
        'X-EBAY-API-SITEID' => @site_id.to_s,
        'Content-Type' => 'multipart/form-data; boundary=MIME_boundary'
      }
    end

    # Gets the body of this request (which is XML)
    def body
        mime_body
    end

    # Returns eBay requester credential XML if @auth_token is present
    def requester_credentials_xml
      return "" unless @auth_token && !@auth_token.empty?

      <<-XML
      <RequesterCredentials>
        <eBayAuthToken>#{@auth_token}</eBayAuthToken>
      </RequesterCredentials>
      XML
    end

    # Makes a HTTP connection and sends the request, returning an
    # Ebayr::Response
    def send
      http = Net::HTTP.new(@uri.host, @uri.port)
      http.read_timeout = @http_timeout

      # Output request XML if debug flag is set
      puts body if debug

      if @uri.port == 443
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      post = Net::HTTP::Post.new(@uri.path, headers)
      post.body = body

      response = http.start { |http| http.request(post) }

      @response = Response.new(self, response)
    end

    def to_s
      "#{@command}[#{@input}] <#{@uri}>"
    end

    private

    def xml_part_of_body
      <<-XML
        <?xml version="1.0" encoding="utf-8"?>
        <#{@command}Request xmlns="urn:ebay:apis:eBLBaseComponents">
          #{requester_credentials_xml}
          #{input_xml}
        </#{@command}Request>
      XML
    end

    def mime_body
      boundary = "MIME_boundary"
      crlf = "\r\n"

      # The complete body consists of an XML request plus the binary attachment separated by boundaries
      first_part  =  "--" + boundary + crlf
      first_part  << 'Content-Disposition: form-data; name="XML Payload"' + crlf
      first_part  << 'Content-Type: text/xml;charset=utf-8' + crlf + crlf
      first_part  << xml_part_of_body
      first_part  << crlf

      unless @attachment
        return first_part + "--" + boundary + "--" + crlf
      end

      second_part =  "--" + boundary + crlf
      second_part << 'Content-Disposition: form-data; name="dummy"; filename="image.jpg' + crlf
      second_part << "Content-Transfer-Encoding: binary" + crlf
      second_part << "Content-Type: application/octet-stream" + crlf + crlf
      second_part << File.read(@attachment)
      second_part << crlf
      second_part << "--" + boundary + "--" + crlf

      first_part + second_part
    end

    def input_xml
      xml @input
    end

    # A very, very simple XML serializer.
    #
    #     Ebayr.xml("Hello!")       # => "Hello!"
    #     Ebayr.xml(:foo=>"Bar")  # => <foo>Bar</foo>
    #     Ebayr.xml([{:foo=>"Bar"}])  # => <foo>Bar</foo>
    #     Ebayr.xml(:foo=>["Bar","Baz"])  # => <foo>Bar</foo><foo>Baz</foo>
    def xml(*args)
      return xml_with_old_conversion(*args) if Ebayr.use_old_hash_to_xml_conversion?

      args = args.flatten
      args.map do |structure|
        case structure
        when Hash
          structure.map do |k, v|
            if Array === v
              v.map { |elem| xml(k => elem) }
            else
              "<#{k.to_s}>#{xml(v)}</#{k.to_s.split.first}>"
            end
          end
        else
          serialize(structure)
        end
      end.join
    end

    # A very, very simple XML serializer.
    #
    #     Ebayr.xml("Hello!")       # => "Hello!"
    #     Ebayr.xml(:foo=>"Bar")  # => <foo>Bar</foo>
    #     Ebayr.xml(:foo=>["Bar","Baz"])  # => <foo>Bar</foo>
    def xml_with_old_conversion(*args)
      args.map do |structure|
        case structure
        when Hash then structure.map { |k, v| "<#{k.to_s}>#{xml(v)}</#{k.to_s}>" }.join
        when Array then structure.map { |v| xml(v) }.join
        else serialize(structure)
        end
      end.join
    end

    # Prepares an argument for input to an eBay Trading API XML call.
    # * Times are converted to ISO 8601 format
    def serialize(input)
      case input
        when Time then input.to_time.utc.iso8601
        else input.to_s.encode :xml => :text
      end
    end

    # Converts a command like get_ebay_offical_time to GeteBayOfficialTime
    def camelize(string)
      string = string.to_s
      return string unless string == string.downcase
      string.split('_').map(&:capitalize).join.gsub('Ebay', 'eBay')
    end

    # Gets a HTTP connection for this request. If you pass in a block, it will
    # be run on that HTTP connection.
    def http(&block)
      http = Net::HTTP.new(@uri.host, @uri.port)
      if @uri.port == 443
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      return http.start(&block) if block_given?
      http
    end
  end
end
