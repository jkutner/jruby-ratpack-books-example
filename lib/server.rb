require 'java'
require 'jruby/core_ext'
require 'bundler/setup'
Bundler.require

require 'net/http'
require 'json'

java_import 'ratpack.server.RatpackServer'
java_import 'ratpack.server.BaseDir'
java_import 'ratpack.http.client.HttpClient'
java_import 'ratpack.rx.RxRatpack'
java_import 'rx.Observable'
java_import 'java.util.Collections'
java_import 'java.lang.System'

DEFAULT_APP_ID = ENV['EBAY_APP_ID']
STYLE = "<style type='text/css'>"+
        "  img.thumb:hover {height:50px}"+
        "  img.thumb {vertical-align:text-top}"+
        "  span.red {color: #ff0000}"+
        "  span.green {color: #00ff00}"+
        "  iframe {border: 0px}"+
        "</style>"

def rest_url(item)
  "http://open.api.ebay.com/shopping?MaxEntries=3&appid=#{DEFAULT_APP_ID}" +
    "&version=573&siteid=0&callname=FindItems&responseencoding=JSON&QueryKeywords=#{item}"
end

def generate_thumbs(results)
  results.map do |result|
    if result.has_key?("GalleryURL")
      "<a href=\"#{result["ViewItemURLForNaturalSearch"]}\">" +
        "<img class='thumb' border='1px' height='25px'" +
        " src='#{result["GalleryURL"]}'"+
        " title='#{result["Title"]}'"+
        "/></a>"
    end
  end.join("&nbsp;")
end

def ms(nano)
  nano / 1000000
end

def width(nano)
  w = (nano+999999)/5000000
  w == 0 ? 2 : w
end

RatpackServer.start do |b|
  b.server_config do |s|
    s.baseDir(BaseDir.find())
  end

  b.handlers do |chain|
    chain.get do |ctx|
      ctx.redirect('/index.html')
    end

    chain.get("async") do |ctx|
      start = System.nano_time

      items = ctx.get_request.get_query_params["items"]
      observables = items.split(",").map do |item|
        uri = java.net.URI.new(rest_url(item))
        http_client = ctx.get(HttpClient.java_class)
        RxRatpack.fork(
          RxRatpack.observe(http_client.get(uri)).map do |response|
            JSON.parse(response.get_body.get_text)["Item"]
          end
        )
      end
      initial = System.nano_time - start

      Observable.merge(observables).to_list.subscribe do |results|
        start2 = System.nano_time
        thumbs = generate_thumbs(results.map{|r|r}.flatten)

        ctx.get_response.get_headers.set("Content-Type", "text/html")

        now = System.nano_time
        total = now - start
        generate = now - start2
        thread = initial + generate

        ctx.render("<html><head>" +
          STYLE +
          "</head><body><small>" +
          "<b>Asynchronous: #{items}</b><br/>" +
          "Total Time: #{ms(total)}ms<br/>" +
          "Thread held (<span class='red'>red</span>): #{ms(thread)}ms (#{ms(initial)} initial + #{ms(generate)} generate )<br/>" +
          "Async wait (<span class='green'>green</span>): #{ms(total-thread)}ms<br/>" +
          "<img border='0px' src='images/red.png' height='20px' width='#{width(initial)}px'>" +
          "<img border='0px' src='images/green.png' height='20px' width='#{width(total-thread)}px'>" +
          "<img border='0px' src='images/red.png' height='20px' width='#{width(generate)}px'>" +
          "<hr />" +
          thumbs +
          "</small>" +
          "</body></html>")
      end
    end

    chain.get("sync") do |ctx|
      start = System.nano_time

      items = ctx.get_request.get_query_params["items"]
      results = items.split(",").map do |item|
        uri = URI(rest_url(item))
        response = Net::HTTP.get(uri)
        JSON.parse(response)["Item"]
      end.flatten
      thumbs = generate_thumbs(results)

      now = System.nano_time
      total = now-start

      ctx.get_response.get_headers.set("Content-Type", "text/html")

      ctx.render("<html><head>" +
        STYLE +
        "</head><body><small>" +
        "<b>Blocking: #{items}</b><br/>" +
        "Total Time: #{ms(total)}ms<br/>" +
        "Thread held (<span class='red'>red</span>): #{ms(total)}ms<br/>" +
        "<img border='0px' src='images/red.png' height='20px' width='#{width(total)}px'>" +
        "<hr />" +
        thumbs +
        "</small>" +
        "</body></html>")
    end

    chain.files do |f|
      f.dir("public")
    end
  end
end
