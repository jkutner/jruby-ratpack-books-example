require 'sequel'
require 'jdbc/postgres'

java_import "com.google.inject.AbstractModule"
java_import "com.google.inject.Scopes"
java_import "com.netflix.hystrix.HystrixObservableCommand"
java_import "com.netflix.hystrix.HystrixCommandGroupKey"
java_import "com.netflix.hystrix.HystrixCommandKey"
java_import "ratpack.rx.RxRatpack"
java_import "ratpack.exec.Blocking"

class BookDbCommands

  DB = Sequel.connect(ENV['JDBC_DATABASE_URL'])
  GROUP_KEY = HystrixCommandGroupKey::Factory.as_key("sql-bookdb")

  def initialize
    unless DB.table_exists?(:books)
      puts "Creating database table"
      ddl = File.read("./db/schema.sql")
      DB.run(ddl)
    end
  end

  def all
    s = HystrixObservableCommand::Setter.
      with_group_key(GROUP_KEY).
      and_command_key(HystrixCommandKey::Factory.as_key("getAll"))

    Class.new(HystrixObservableCommand) do
      def construct
        RxRatpack.observe_each(Blocking.get {
          DB["select isbn, quantity, price from books order by isbn"].all
        })
      end

      def get_cache_key
        "db-bookdb-all"
      end
    end.new(s).to_observable
  end

  def find(isbn)
    s = HystrixObservableCommand::Setter.
      with_group_key(GROUP_KEY).
      and_command_key(HystrixCommandKey::Factory.as_key("find"))

    Class.new(HystrixObservableCommand) do
      def initialize(setter, isbn)
        super(setter)
        @isbn = isbn
      end

      def construct
        RxRatpack.observe_each(Blocking.get {
          DB["select isbn, quantity, price from books where isbn = ?", @isbn].all
        })
      end

      def get_cache_key
        "db-bookdb-all"
      end
    end.new(s, isbn).to_observable
  end

  def insert(values)
    s = HystrixObservableCommand::Setter.
      with_group_key(GROUP_KEY).
      and_command_key(HystrixCommandKey::Factory.as_key("insert"))

    Class.new(HystrixObservableCommand) do
      def initialize(setter, values)
        super(setter)
        @values = values
      end

      def construct
        RxRatpack.observe(Blocking.get {
          DB[:books].insert(@values)
        })
      end
    end.new(s, values).to_observable
  end

  def update(values)
    s = HystrixObservableCommand::Setter.
      with_group_key(GROUP_KEY).
      and_command_key(HystrixCommandKey::Factory.as_key("update"))

    Class.new(HystrixObservableCommand) do
      def initialize(setter, values)
        super(setter)
        @values = values
      end

      def construct
        RxRatpack.observe(Blocking.get {
          DB[
            "update books set quantity = ?, price = ? where isbn = ?",
            @values[:quantity],
            @values[:price],
            @values[:isbn],
          ].update
        })
      end
    end.new(s, values).to_observable
  end

  def delete(isbn)
    s = HystrixObservableCommand::Setter.
      with_group_key(GROUP_KEY).
      and_command_key(HystrixCommandKey::Factory.as_key("delete"))

    Class.new(HystrixObservableCommand) do
      def initialize(setter, isbn)
        super(setter)
        @isbn = isbn
      end

      def construct
        RxRatpack.observe(Blocking.get {
          DB["delete from books where isbn = ?", @isbn].delete
        })
      end
    end.new(s, isbn).to_observable
  end
end
