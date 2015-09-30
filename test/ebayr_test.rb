# -*- encoding : utf-8 -*-
require 'test_helper'
require 'ebayr'
require 'ebayr/api'
require 'fakeweb'

def check_common_methods(mod = Ebayr)
  assert_respond_to mod, :"dev_id"
  assert_respond_to mod, :"cert_id"
  assert_respond_to mod, :"ru_name"
  assert_respond_to mod, :"auth_token"
  assert_respond_to mod, :"compatability_level"
  assert_respond_to mod, :"site_id"
  assert_respond_to mod, :"sandbox"
  assert_respond_to mod, :"authorization_callback_url"
  assert_respond_to mod, :"authorization_failure_url"
  assert_respond_to mod, :"callbacks"
  assert_respond_to mod, :"logger"
  assert_respond_to mod, :"uri"
end

describe Ebayr do

  let(:ebayr) { Ebayr }
  let(:xml) { "<GeteBayOfficialTimeResponse><Ack>Succes</Ack><Timestamp>blah</Timestamp></GeteBayOfficialTimeResponse>" }

  before { FakeWeb.register_uri(:post, ebayr.uri, :body => xml) }

  it "works when as an extension" do
    mod = Module.new { extend Ebayr }
    check_common_methods(mod)
  end

  it "works as an inclusion" do
    klass = Class.new { include Ebayr }
    check_common_methods(klass.new)
  end

  it "runs without exceptions" do
    ebayr.call(:GeteBayOfficialTime).timestamp.must_equal 'blah'
  end

  it "correctly reports its sandbox status" do
    ebayr.sandbox = false
    ebayr.wont_be :sandbox?
    # because state doesnt get reset when testing Ebayr
    ebayr.sandbox = true
  end

  it "has the right sandbox URIs" do
    ebayr.uri_prefix.must_equal "https://api.sandbox.ebay.com/ws"
    ebayr.uri_prefix("blah").must_equal "https://blah.sandbox.ebay.com/ws"
    ebayr.uri.to_s.must_equal "https://api.sandbox.ebay.com/ws/api.dll"
  end

  it "has the right real-world URIs" do
    ebayr.sandbox = false
    ebayr.uri_prefix.must_equal "https://api.ebay.com/ws"
    ebayr.uri_prefix("blah").must_equal "https://blah.ebay.com/ws"
    ebayr.uri.to_s.must_equal "https://api.ebay.com/ws/api.dll"
    # because state doesnt get reset when testing Ebayr
    ebayr.sandbox = true
  end

  it "has the right methods" do
    check_common_methods
    assert_respond_to Ebayr, :"dev_id="
    assert_respond_to Ebayr, :"cert_id="
    assert_respond_to Ebayr, :"ru_name="
    assert_respond_to Ebayr, :"auth_token="
    assert_respond_to Ebayr, :"compatability_level="
    assert_respond_to Ebayr, :"site_id="
    assert_respond_to Ebayr, :"sandbox="
    assert_respond_to Ebayr, :"authorization_callback_url="
    assert_respond_to Ebayr, :"authorization_failure_url="
    assert_respond_to Ebayr, :"callbacks="
    assert_respond_to Ebayr, :"logger="
  end

  it "has decent defaults" do
    ebayr.must_be :sandbox?
    ebayr.uri.to_s.must_equal "https://api.sandbox.ebay.com/ws/api.dll"
    ebayr.logger.must_be_kind_of Logger
  end
end

describe Ebayr::API do

  let(:xml) { "<GeteBayOfficialTimeResponse><Ack>Succes</Ack><Timestamp>blah</Timestamp></GeteBayOfficialTimeResponse>" }
  let(:sandbox) { true }
  let(:ebayr) do
    options = {}
    Ebayr::API::REQUIRED_OPTIONS.each do |key|
      options[key] = 'dummy-value'
    end
    Ebayr::API.new options.merge(:sandbox => sandbox)
  end

  it "has the right sandbox URIs" do
    ebayr.uri_prefix.must_equal "https://api.sandbox.ebay.com/ws"
    ebayr.uri_prefix("blah").must_equal "https://blah.sandbox.ebay.com/ws"
    ebayr.uri.to_s.must_equal "https://api.sandbox.ebay.com/ws/api.dll"
  end

  before { FakeWeb.register_uri(:post, ebayr.uri, :body => xml) }

  it "runs without exceptions" do
    ebayr.call(:GeteBayOfficialTime).timestamp.must_equal 'blah'
  end

  it "correctly reports its sandbox status" do
    ebayr.must_be :sandbox?
  end

  it "has the right methods" do
    check_common_methods ebayr
  end

  it "has decent defaults" do
    ebayr.logger.must_be_kind_of Logger
  end

  describe 'in production mode' do
    let(:sandbox) { false }

    it "has the right real-world URIs" do
      ebayr.uri_prefix.must_equal "https://api.ebay.com/ws"
      ebayr.uri_prefix("blah").must_equal "https://blah.ebay.com/ws"
      ebayr.uri.to_s.must_equal "https://api.ebay.com/ws/api.dll"
    end

    it "correctly reports its sandbox status" do
      ebayr.wont_be :sandbox?
    end
  end
end
