require 'didkit'

module Utils
  def handle_from_did(did)
    DID.new(did).get_validated_handle
  end

  def did_from_handle(handle)
    DID.resolve_handle(handle).did
  end

  extend self
end
