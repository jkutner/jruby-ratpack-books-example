require 'java'
require 'jruby/core_ext'
require 'bundler/setup'
Bundler.require

require 'net/http'
require 'json'

java_import 'ratpack.server.RatpackServer'
java_import 'ratpack.server.BaseDir'
java_import 'ratpack.http.client.HttpClient'
java_import 'java.lang.System'

DEFAULT_APP_ID="Webtide81-adf4-4f0a-ad58-d91e41bbe85"
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
    chain.get("async") do |ctx|
      start = System.nano_time

      items = ctx.get_request.get_query_params["items"]
      results =
      items.split(",").each do |item|
        uri = URI(rest_url(item))
        http_client = ctx.get(HttpClient.class)
        http_client.get(remoteApp.getAddress()).then do |response|

        end
      end
      thumbs = generate_thumbs(results)
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
