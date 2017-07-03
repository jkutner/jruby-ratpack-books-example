java_import "com.google.inject.AbstractModule"
java_import "com.google.inject.Scopes"

class BookModule < AbstractModule
  def configure
    bind(BookService.class).in(Scopes.SINGLETON);
    # bind(BookRenderer.class).in(Scopes.SINGLETON);
    # bind(BookRestEndpoint.class).in(Scopes.SINGLETON);
    # bind(BookDbCommands.class).in(Scopes.SINGLETON);
    # bind(IsbnDbCommands.class).in(Scopes.SINGLETON);
  end
end
