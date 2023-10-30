require 'json'
require 'open-uri'

module Utils
  def handle_from_did(did)
    url = "https://plc.directory/#{did}"
    json = JSON.parse(URI.open(url).read)
    json['alsoKnownAs'][0].gsub('at://', '')
  end

  def did_from_handle(handle)
    url = "https://bsky.social/xrpc/com.atproto.identity.resolveHandle?handle=#{handle}"
    json = JSON.parse(URI.open(url).read)
    json['did']
  end

  extend self
end
