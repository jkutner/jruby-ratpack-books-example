java_import "rx.Observable"

require 'json'
require_relative "book_db_commands"
require_relative "isbn_db_commands"

class BookService

  def initialize
    @db = BookDbCommands.new
    @isbn_db = IsbnDbCommands.new
  end

  def all(ctx)
    @db.all.flat_map do |row|
      @isbn_db.get_book(ctx, row[:isbn]).map do |json|
        row.merge(JSON.parse(json))
      end
    end
  end

  def insert(values)
    @db.insert(values).map { values[:isbn] }
  end

  def update(values)
    @db.update(values).map { values[:isbn] }
  end

  def find(ctx, isbn)
    Observable.zip(
      @db.find(isbn),
      @isbn_db.get_book(ctx, isbn)
    ) do |row, json|
      row.merge(JSON.parse(json))
    end
  end

  def delete(isbn)
    @db.delete(isbn).map { isbn }
  end

end
