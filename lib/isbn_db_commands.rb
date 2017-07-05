java_import "com.google.inject.AbstractModule"
java_import "com.google.inject.Scopes"
java_import "com.netflix.hystrix.HystrixObservableCommand"
java_import "com.netflix.hystrix.HystrixCommandGroupKey"
java_import "com.netflix.hystrix.HystrixCommandKey"
java_import "ratpack.rx.RxRatpack"
java_import "ratpack.exec.Blocking"
java_import "ratpack.http.client.HttpClient"
java_import "rx.Observable"

class IsbnDbCommands

  HOST = ENV['ISBN_HOST'] || "http://isbndb.org"
  KEY = ENV['ISBN_KEY'] || raise("Missing ISBN service API key!")

  def get_book(ctx, isbn)
    http_client = ctx.get(HttpClient.java_class)

    s = HystrixObservableCommand::Setter.
      with_group_key(HystrixCommandGroupKey::Factory.as_key("http-isbndb")).
      and_command_key(HystrixCommandKey::Factory.as_key("getBookRequest"))

    Class.new(HystrixObservableCommand) do
      def initialize(setter, http_client, isbn)
        super(setter)
        @http_client = http_client
        @isbn = isbn
      end

      def construct
        uri = java.net.URI.new("#{HOST}/api/v2/json/#{KEY}/book/#{@isbn}")
        RxRatpack.observe(@http_client.get(uri)).map do |resp|
          if resp.body.text.include?("Daily request limit exceeded")
            raise "ISBNDB daily request limit exceeded."
          end
          resp.body.text
        end
      end

      def resumeWithFallback
        Observable.just('{"error" : "Timeout"}')
      end

      def get_cache_key
        "http-isbndb-book-#{@isbn}"
      end
    end.new(s, http_client, isbn).to_observable
  end
end
