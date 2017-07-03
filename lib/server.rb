require 'java'
require 'jruby/core_ext'
require 'bundler/setup'
Bundler.require

require_relative "book_service"

java_import 'ratpack.server.RatpackServer'
java_import 'ratpack.server.BaseDir'
java_import 'ratpack.guice.Guice'
java_import 'ratpack.session.SessionModule'
java_import 'ratpack.hystrix.HystrixModule'

RatpackServer.start do |b|
  b.server_config do |s|
    s.baseDir(BaseDir.find())
    # s.props("application.properties")
  end

  b.registry(
    Guice.registry do |bindings|
      bindings.module SessionModule.java_class
      bindings.module HystrixModule.new.sse
    end
  )

  b.handlers do |chain|
    chain.get do |ctx|
      BookService.all.to_list.subscribe do |books|
        ctx.render "index.html.erb"
      end
    end

    chain.path("create") do |c|
      c.by_method do |m|
        m.get do |ctx|
          BookService.all.to_list.subscribe do |books|
            ctx.render "create.html.erb"
          end
        end

        m.post do |ctx|
          # todo
          ctx.redirect "/?msg=Book+#{isbn}+created"
        end
      end
    end

    chain.path("update/:isbn") do |c|
      isbn = c.path_tokens["isbn"]

      BookService.find(isbn).single.subscribe do |book|
        if book.nil?
          client_error(404)
        else
          c.by_method do |m|
            m.get do |ctx|
              ctx.render "update.html.erb"
            end
            m.post do |ctx|
              # todo
              ctx.redirect "/?msg=Book+#{isbn}+updated"
            end
          end
        end
      end

      chain.delete("delete/:isbn") do |ctx|
        isbn = c.path_tokens["isbn"]
        BookService.delete(isbn).subscribe do
          ctx.redirect "/?msg=Book+#{isbn}+deleted"
        end
      end
    end

    chain.files do |f|
      f.dir("public")
    end
  end
end
