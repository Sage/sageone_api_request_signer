require "sageone_api_request_signer/version"
require "active_support"
require "active_support/core_ext"
require "base64"

# Sign a Sage One API request call following the steps detailed here:
# https://developers.sageone.com/docs#signing_your_requests
class SageoneApiRequestSigner

  attr_accessor :request_method, :url, :body_params, :nonce, :signing_secret, :access_token

  def initialize(params = {})
    params.each do |attr, val|
      self.public_send("#{attr}=", val)
    end
  end

  def request_method
    @request_method.to_s.upcase
  end

  def nonce
    @nonce ||= SecureRandom.hex
  end

  def uri
    @uri ||= URI(url)
  end

  # Return the base URL without query string and fragment
  def base_url
    @base_url ||= [
      uri.scheme,
      '://',
      uri.host,
      uri_port_string,
      uri.path
    ].join
  end

  def url_params
    @url_params ||= Hash[URI::decode_www_form(uri.query || '')]
  end

  def parameter_string
    @parameter_string ||= (
      Hash[url_params.merge(body_params).sort].to_query.gsub('+','%20')
    )
  end

  def signature_base_string
    @signature_base_string ||= [
      request_method,
      percent_encode(base_url),
      percent_encode(parameter_string),
      percent_encode(nonce)
    ].join('&')
  end

  def signing_key
    @signing_key ||= [
      percent_encode(signing_secret),
      percent_encode(access_token)
    ].join('&')
  end

  # generate a Base64 encoded signature
  def signature
    @signature ||= Base64.encode64(OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha1'), signing_key, signature_base_string))
  end

  # The request headers
  def request_headers(user_agent)
    {
      'Authorization' => "Bearer #{access_token}",
      'X-Nonce' => nonce,
      'X-Signature' => signature,
      'Accept' => '*/*',
      'Content-Type' => 'application/x-www-form-urlencoded',
      'User-Agent' => user_agent
    }
  end

  private

  def percent_encode(str)
    URI.escape(str.to_s, /[^0-9A-Za-z\-._~]/)
  end

  def uri_port_string
    uri.port == uri.default_port ? "" : ":#{uri.port}"
  end
end
