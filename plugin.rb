# name: discourse-facebook-onebox
# about: Discourse Onebox to display Facebook elements
# version: 0.2
# authors: Huan Nghiem
# url: https://github.com/nightshadecf/discourse-facebook-onebox

# javascript
register_asset "javascripts/embedFB.js"

# Without this, there is an error when loading/precompiling:
# NoMethodError: undefined method `matches_regexp'
Onebox = Onebox

module Onebox
  module Engine
    class FacebookOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/.*facebook\.com/)
      always_https

      def to_html
        oembed_data = get_html
      end

      def placeholder_html
        oembed_data = get_html
      end

      private
      def self.fetch_response(location, limit = 5, domain = nil, headers = nil)
        raise Net::HTTPError.new('HTTP redirect too deep', location) if limit == 0

        uri = URI(location)
        if !uri.host
          uri = URI("#{domain}#{location}")
        end
        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = Onebox.options.connect_timeout
        http.read_timeout = Onebox.options.timeout
        if uri.is_a?(URI::HTTPS)
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        headers['accept-language'] = 'vi' if headers.is_a? Hash
        headers = {'accept-language' => 'vi'} if headers == nil

        response = http.request_get(uri.request_uri,headers)

        cookie = response.get_fields('set-cookie')
        if (cookie)
          header = {'cookie' => cookie.join("")}
        end
        header = nil unless header.is_a? Hash

        case response
          when Net::HTTPSuccess     then response
          when Net::HTTPRedirection then fetch_response(response['location'], limit - 1, "#{uri.scheme}://#{uri.host}",header)
          else
            response.error!
        end
      end			
      def video?
        url =~ /\/video.php\?|\/videos\//
      end

      def get_html
        if video?
          data = get_oembed_data[:html]
          data = data.sub! 'fb-video', 'fb-xfbml-parse-ignore video'
        else
          data = get_oembed_data[:html]
          data = data.sub! 'fb-post', 'fb-xfbml-parse-ignore post'
        end
	  end

      def get_oembed_data
        if video?
          Onebox::Helpers.symbolize_keys(::MultiJson.load(fetch_response("https://facebook.com/plugins/video/oembed.json?url=#{url}&maxwidth=661&omitscript=true").body))
        else
          Onebox::Helpers.symbolize_keys(::MultiJson.load(fetch_response("https://facebook.com/plugins/post/oembed.json?url=#{url}&maxwidth=661&omitscript=true").body))
        end
      end
    end
  end
end
