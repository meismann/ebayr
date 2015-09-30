module Ebayr
  class API

    # See http://developer.ebay.com/DevZone/XML/docs/HowTo/index.html for more
    # details.
    REQUIRED_OPTIONS = [
      :dev_id, :app_id, :cert_id, :ru_name, :auth_token
    ]
    REQUIRED_OPTIONS.map &method(:attr_reader)

    OPTIONS_WITH_DEFAULTS = {
      # Determines whether to use the eBay sandbox or the real site.
      :sandbox => true,
      # Use this if your code relies on a version of this gem up to 0.0.10
      :use_old_hash_to_xml_conversion => false,
      # Set to true to generate fancier objects for responses (will decrease performance).
      :normalize_responses => false,
      # This URL is used to redirect the user back after a successful registration.
      # For more details, see here:
      # http://developer.ebay.com/DevZone/XML/docs/WebHelp/wwhelp/wwhimpl/js/html/wwhelp.htm?context=eBay_XML_API&topic=GettingATokenViaFetchToken
      :authorization_callback_url => 'https://example.com/',
      # This URL is used if the authorization process fails - usually because the user
      # didn't click 'I agree'. If you leave it nil, the
      # <code>authorization_callback_url</code> will be used (but the parameters will be
      # different).
      :authorization_failure_url => nil,
      # Callbacks which are invoked at various points throughout a request.
      :callbacks => {
        :before_request   => [],
        :after_request    => [],
        :before_response  => [],
        :after_response   => [],
        :on_error         => []
      },
      # The eBay Site to use for calls. The full list of available sites can be
      # retrieved with <code>GeteBayDetails(:DetailName => "SiteDetails")</code>
      :site_id => 0,
      # eBay Trading API version to use. For more details, see
      # http://developer.ebay.com/devzone/xml/docs/HowTo/eBayWS/eBaySchemaVersioning.html
      :compatability_level => 837,
      :logger => (logger = Logger.new(STDOUT); logger.level = Logger::INFO; logger),
      :debug => false,
    }
    OPTIONS_WITH_DEFAULTS.keys.map &method(:attr_reader)

    def initialize(options)
      set_required_options(options)
      set_options_with_defaults(options)
    end

    def method_missing(method, *args, &block)
      if respond_to?(method.to_s.chomp('?'))
        !!send(method.to_s.chop)
      else
        super
      end
    end

    # Gets either ebay.com/ws or sandbox.ebay.com/ws, as appropriate, with
    # "service" prepended. E.g.
    #
    #     Ebayr.uri_prefix("blah")  # => https://blah.ebay.com/ws
    #     Ebayr.uri_prefix          # => https://api.ebay.com/ws
    def uri_prefix(service = "api")
      "https://#{service}#{sandbox? ? ".sandbox" : ""}.ebay.com/ws"
    end

    # Gets the URI used for API calls (as a URI object)
    def uri
      URI::parse("#{uri_prefix}/api.dll")
    end

    # Gets the URI for eBay authorization/login. The session_id should be obtained
    # via an API call to GetSessionID (be sure to use the right ru_name), and the
    # ru_params can contain anything (they will be passed back to your app in the
    # redirect from eBay upon successful login and authorization).
    def authorization_uri(session_id, ru_params = {})
      ruparams = CGI::escape(ru_params.map { |k, v| "#{k}=#{v}" }.join("&"))
      URI::parse("#{uri_prefix("signin")}/eBayISAPI.dll?SignIn&RuName=#{ru_name}&SessId=#{session_id}&ruparams=#{ruparams}")
    end

    # Perform an eBay call (symbol or string). You can pass in these arguments:
    #
    # auth_token:: to use a user's token instead of the general token
    # site_id:: to use a specific eBay site (default is 0, which is US ebay.com)
    # compatability_level:: declare another eBay Trading API compatability_level
    #
    # All other arguments are passed into the API call, and may be nested.
    #
    #     response = call(:GeteBayOfficialTime)
    #     response = call(:get_ebay_official_time)
    #
    # See Ebayr::Request for details.
    #
    # The response is a special Hash of the response, deserialized from the XML
    #
    #     response.timestamp     # => 2010-10-10 10:00:00 UTC
    #     response[:timestamp]   # => 2010-10-10 10:00:00 UTC
    #     response['Timestamp']  # => "2012-10-10T10:00:00.000Z"
    #     response[:Timestamp]   # => "2012-10-10T10:00:00.000Z"
    #     response.ack           # "Success"
    #     response.success?      # true
    #
    #  See Ebayr::Response for details.
    #
    #  To see a list of available calls, check out
    #  http://developer.ebay.com/DevZone/XML/docs/Reference/ebay/index.html
    def call(command, arguments = {})
      Request.new(self, command, arguments).send
    end

    private

    def set_required_options(options)
      missing_options = REQUIRED_OPTIONS - options.keys
      if missing_options.any?
        raise "Set options #{missing_options} when calling #{self.class.name}.new"
      end

      options.each do |k, v|
        instance_variable_set("@#{k}", v) if REQUIRED_OPTIONS.include? k
      end
    end

    def set_options_with_defaults(options)
      OPTIONS_WITH_DEFAULTS.each do |k, v|
        instance_variable_set("@#{k}", (options.has_key?(k) ? options[k] : OPTIONS_WITH_DEFAULTS[k]))
      end
    end

  end
end
