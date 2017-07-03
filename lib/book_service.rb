java_import "com.google.inject.AbstractModule"
java_import "com.google.inject.Scopes"
java_import "com.netflix.hystrix.HystrixObservableCommand"
java_import "com.netflix.hystrix.HystrixCommandGroupKey"
java_import "ratpack.rx.RxRatpack"
java_import "ratpack.exec.Blocking"

module BookService

  @group_key = HystrixCommandGroupKey::Factory.as_key("sql-bookdb")

  def self.all
    s = HystrixObservableCommand::Setter.with_group_key(@group_key)

    command = Class.new(HystrixObservableCommand) do
      def construct
        RxRatpack.observe_each(Blocking.get {
          # sql.rows("select isbn, quantity, price from books order by isbn")
          puts "test"
          []
        })
      end

      def get_cache_key
        "db-bookdb-all"
      end
    end

    command.new(s).to_observable
  end

  def self.find(isbn)

  end

  def self.delete(isbn)

  end

end
