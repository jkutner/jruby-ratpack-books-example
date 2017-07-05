require 'java'
require 'jruby/core_ext'
require 'bundler/setup'
Bundler.require

require 'erb'

require_relative "book_service"

java_import 'ratpack.server.RatpackServer'
java_import 'ratpack.server.BaseDir'
java_import 'ratpack.guice.Guice'
java_import 'ratpack.session.SessionModule'
java_import 'ratpack.hystrix.HystrixMetricsEventStreamHandler'
java_import 'ratpack.hystrix.HystrixModule'
java_import 'ratpack.rx.RxRatpack'
java_import 'ratpack.form.Form'
java_import 'ratpack.service.Service'

def render_erb(ctx, template_file, b=binding)
  script = File.open(File.join("views", template_file)).read
  template = ERB.new(script)
  ctx.get_response.get_headers.set("Content-Type", "text/html")
  ctx.render(template.result(b))
end

RatpackServer.start do |b|
  b.server_config do |s|
    s.baseDir(BaseDir.find())
  end

  b.registry(Guice.registry do |bindings|
    bindings.module SessionModule.java_class
    bindings.module HystrixModule.new.sse
  end)

  b.handlers do |chain|
    book_service = BookService.new

    chain.get do |ctx|
      book_service.all(ctx).to_list.subscribe do |books|
        render_erb(ctx, "index.html.erb", binding)
      end
    end

    chain.path("create") do |ctx|
      ctx.by_method do |m|
        m.get do
          render_erb(ctx, "create.html.erb")
        end

        m.post do
          RxRatpack.observe(ctx.parse(Form.java_class)).flat_map do |form|
            book_service.insert(
              isbn: form["isbn"],
              quantity: form["quantity"].to_i,
              price: form["price"].to_f)
          end.single.subscribe do |isbn|
            ctx.redirect "/?msg=Book+#{isbn}+created"
          end
        end
      end
    end

    chain.path("update/:isbn") do |ctx|
      isbn = ctx.path_tokens["isbn"]

      book_service.find(ctx, isbn).single.subscribe do |book|
        if book.nil?
          client_error(404)
        else
          ctx.by_method do |m|
            m.get do
              render_erb(ctx, "update.html.erb", binding)
            end
            m.post do
              RxRatpack.observe(ctx.parse(Form.java_class)).flat_map do |form|
                book_service.update(
                  isbn: form["isbn"],
                  quantity: form["quantity"].to_i,
                  price: form["price"].to_f)
              end.single.subscribe do |isbn|
                ctx.redirect "/?msg=Book+#{isbn}+updated"
              end
            end
          end
        end
      end
    end

    chain.post("delete/:isbn") do |ctx|
      isbn = ctx.path_tokens["isbn"]
      book_service.delete(isbn).subscribe do
        ctx.redirect "/?msg=Book+#{isbn}+deleted"
      end
    end

    chain.files do |f|
      f.dir("public")
    end

    chain.get("hystrix.stream", HystrixMetricsEventStreamHandler.new)
  end
end
