require "uri"
module Rack
  module Test

    class Cookie
      include Rack::Utils

      # :api: private
      attr_reader :name, :value

      # :api: private
      def initialize(raw, uri = nil, default_host = DEFAULT_HOST)
        uri ||= default_uri
        # separate the name / value pair from the cookie options
        @name_value_raw, options = raw.split(/[;,] */n, 2)

        @name, @value = parse_query(@name_value_raw, ';').to_a.first
        @options = parse_query(options, ';')

        @options["domain"]  ||= (uri.host || default_host)
        @options["path"]    ||= uri.path.sub(/\/[^\/]*\Z/, "")
      end

      def replaces?(other)
        [name.downcase, domain, path] == [other.name.downcase, other.domain, other.path]
      end

      # :api: private
      def raw
        @name_value_raw
      end

      # :api: private
      def empty?
        @value.nil? || @value.empty?
      end

      # :api: private
      def domain
        @options["domain"]
      end

      def secure?
        @options.has_key?("secure")
      end

      # :api: private
      def path
        @options["path"] || "/"
      end

      # :api: private
      def expires
        Time.parse(@options["expires"]) if @options["expires"]
      end

      # :api: private
      def expired?
        expires && expires < Time.now
      end

      # :api: private
      def valid?(uri)
        (!secure? || (secure? && uri.scheme == "https")) &&
        uri.host =~ Regexp.new("#{Regexp.escape(domain)}$", Regexp::IGNORECASE) &&
        uri.path =~ Regexp.new("^#{Regexp.escape(path)}")
      end

      # :api: private
      def matches?(uri)
        ! expired? && valid?(uri)
      end

      # :api: private
      def <=>(other)
        # Orders the cookies from least specific to most
        [name, path, domain.reverse] <=> [other.name, other.path, other.domain.reverse]
      end

    protected

      def default_uri
        URI.parse("//" + @default_host + "/")
      end

    end

    class CookieJar

      # :api: private
      def initialize(cookies = [], default_host = DEFAULT_HOST)
        @default_host = default_host
        @cookies = cookies
        @cookies.sort!
      end

      def merge(raw_cookies, uri = nil)
        return self unless raw_cookies

        uri ||= default_uri

        # Initialize all the the received cookies
        cookies = []
        raw_cookies.each do |raw|
          c = Cookie.new(raw, uri, @default_host)
          self << c if c.valid?(uri)
        end
      end

      def <<(new_cookie)
        @cookies.reject! do |existing_cookie|
          new_cookie.replaces?(existing_cookie)
        end

        @cookies << new_cookie
      end

      # :api: private
      def for(uri)
        hash_for(uri).values.map { |c| c.raw }.join(';')
      end

    protected

      def hash_for(uri)
        cookies = {}

        # The cookies are sorted by most specific first. So, we loop through
        # all the cookies in order and add it to a hash by cookie name if
        # the cookie can be sent to the current URI. It's added to the hash
        # so that when we are done, the cookies will be unique by name and
        # we'll have grabbed the most specific to the URI.
        @cookies.each do |cookie|
          cookies[cookie.name] = cookie if cookie.matches?(uri)
        end

        return cookies
      end

      def default_uri
        URI.parse("//" + @default_host + "/")
      end

    end

  end
end
