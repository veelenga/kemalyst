require "./spec_helper"

describe Kemalyst::Handler::Params do
  context "query params" do
    it "parses query params" do
      request = HTTP::Request.new("GET", "/?test=test")
      io, context = create_context(request)
      params = Kemalyst::Handler::Params.instance
      params.call(context)
      context.params["test"].should eq "test"
    end

    it "parses multiple query params" do
      request = HTTP::Request.new("GET", "/?test=test&test2=test2")
      io, context = create_context(request)
      params = Kemalyst::Handler::Params.instance
      params.call(context)
      context.params["test2"].should eq "test2"
    end
  end

  context "body params" do
    it "parses body params" do
      headers = HTTP::Headers.new
      headers["Content-Type"] = "application/x-www-form-urlencoded"
      body = "test=test"
      request = HTTP::Request.new("POST", "/", headers, body)
      io, context = create_context(request)
      params = Kemalyst::Handler::Params.instance
      params.call(context)
      context.params["test"].should eq "test"
    end

    it "parses body params with charset" do
      headers = HTTP::Headers.new
      headers["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
      body = "test=test"
      request = HTTP::Request.new("POST", "/", headers, body)
      io, context = create_context(request)
      params = Kemalyst::Handler::Params.instance
      params.call(context)
      context.params["test"]?.should eq "test"
    end

    it "parses multiple body params" do
      headers = HTTP::Headers.new
      headers["Content-Type"] = "application/x-www-form-urlencoded"
      body = "test=test&test2=test2"
      request = HTTP::Request.new("POST", "/", headers, body)
      io, context = create_context(request)
      params = Kemalyst::Handler::Params.instance
      params.call(context)
      context.params["test2"].should eq "test2"
    end
  end

  context "json content-type" do
    it "parses json hash" do
      headers = HTTP::Headers.new
      headers["Content-Type"] = "application/json"
      body = "{\"test\":\"test\"}"
      request = HTTP::Request.new("POST", "/", headers, body)
      io, context = create_context(request)
      params = Kemalyst::Handler::Params.instance
      params.call(context)
      context.params["test"].should eq "test"
    end

    it "parses json array" do
      headers = HTTP::Headers.new
      headers["Content-Type"] = "application/json"
      body = "[\"test\",\"test2\"]"
      request = HTTP::Request.new("POST", "/", headers, body)
      io, context = create_context(request)
      params = Kemalyst::Handler::Params.instance
      params.call(context)
      context.params["_json"].should eq "[\"test\", \"test2\"]"
    end
  end

  context "multi-part form" do
    it "parses files from multipart forms" do
      headers = HTTP::Headers.new
      # headers["Content-Type"] = "multipart/form-data; boundary=aA40"
      headers["Content-Type"] = "multipart/form-data; boundary=fhhRFLCazlkA0dX"
      body = "--fhhRFLCazlkA0dX\r\nContent-Disposition: form-data; name=\"_csrf\"\r\n\r\nPcCFp4oKJ1g-hZ-P7-phg0alC51pz7Pl12r0ZOncgxI\r\n--fhhRFLCazlkA0dX\r\nContent-Disposition: form-data; name=\"title\"\r\n\r\ntitle field\r\n--fhhRFLCazlkA0dX\r\nContent-Disposition: form-data; name=\"picture\"; filename=\"index.html\"\r\nContent-Type: text/html\r\n\r\n<head></head><body>Hello World!</body>\r\n\r\n--fhhRFLCazlkA0dX\r\nContent-Disposition: form-data; name=\"content\"\r\n\r\nseriously\r\n--fhhRFLCazlkA0dX--"
      # body = "--aA40\r\nContent-Disposition: form-data; name=\"file1\"; filename=\"field.txt\"\r\n\r\nfield data\r\n--aA40--"
      request = HTTP::Request.new("POST", "/", headers, body)
      io, context = create_context(request)
      params = Kemalyst::Handler::Params.instance
      params.call(context)
      context.files["picture"].filename.should eq "index.html"
      context.params["title"].should eq "title field"
      context.params["_csrf"].should eq "PcCFp4oKJ1g-hZ-P7-phg0alC51pz7Pl12r0ZOncgxI"
    end
  end
end
