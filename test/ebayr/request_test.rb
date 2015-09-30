# -*- encoding : utf-8 -*-
require 'test_helper'
require 'ebayr/request'

def xml_of(*args)
  Ebayr::Request.new(ebayr_api, :Blah, :input => args).__send__ :input_xml
end

describe Ebayr::Request do

  let(:auth_token) { 'auth_token_123xyz' }
  let(:ebayr_api) do
    options = {}
    Ebayr::API::REQUIRED_OPTIONS.each do |key|
      if key == :auth_token
        options[key] = auth_token
      else
        options[key] = 'dummy-value'
      end
    end
    Ebayr::API.new options
  end


  describe "uri" do
    it "is the Ebayr one" do
      Ebayr::Request.new(ebayr_api, :Blah).uri.must_equal(Ebayr.uri)
    end
  end

  describe 'xml conversion' do
    it 'converts Time' do
      xml_of(Time.utc(2010, 'oct', 31, 03, 15)).
        must_equal "2010-10-31T03:15:00Z"
    end

    it "converts multiple arguments in new function" do
      xml_of(:a => [ 1, { :b => [1, 2] } ]).
        must_equal '<a>1</a><a><b>1</b><b>2</b></a>'
    end

    it "converts a hash" do
      xml_of(:a => { :b => 123 }).must_equal '<a><b>123</b></a>'
    end

    it "converts an array" do
      xml_of([{ :a => 1 }, { :a => 2 }]).must_equal "<a>1</a><a>2</a>"
    end

    it "converts a string" do
      xml_of('boo').must_equal 'boo'
    end

    it "converts a number" do
      xml_of(1234).must_equal '1234'
    end

    it "converts multiple arguments" do
      args = [{ :a => 1 }, { :a => {:b => [1, 2] }}]
      xml_of(*args).must_equal '<a>1</a><a><b>1</b><b>2</b></a>'
    end
  end

  describe 'requester credentials' do
    it 'includes requester credentials when auth_token present' do
      request = Ebayr::Request.new(ebayr_api, :Blah)
      request.body.must_include "<RequesterCredentials>", "</RequesterCredentials>"
      request.body.must_include "<eBayAuthToken>#{auth_token}</eBayAuthToken>"
    end

    describe "authentication is not given" do
      let(:auth_token) { nil }

      it 'excludes requester credentials' do
        request = Ebayr::Request.new(ebayr_api, :Blah)
        request.body.wont_include "<RequesterCredentials>", "</RequesterCredentials>"
        request.body.wont_include "<eBayAuthToken>", "</eBayAuthToken>"
      end
    end
  end

  describe 'xml conversion the old way' do
    before do
      @use_old_hash_to_xml_conversion = Ebayr.use_old_hash_to_xml_conversion
      Ebayr.use_old_hash_to_xml_conversion = true
    end

    it "converts multiple arguments in new function" do
      arg = [{ :a => 1 }, { :a => [{:b => 1 }, { :b => 2 }] }]
      xml_of(arg).must_equal '<a>1</a><a><b>1</b><b>2</b></a>'
    end

    it "converts multiple arguments" do
      arg = [{ :a => 1 }, { :a => [{:b => 1 }, { :b => 2 }] }]
      xml_of(*arg).must_equal '<a>1</a><a><b>1</b><b>2</b></a>'
    end

    after do
      Ebayr.use_old_hash_to_xml_conversion = @use_old_hash_to_xml_conversion
    end
  end

end
