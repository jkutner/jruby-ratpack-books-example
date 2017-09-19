# Ratpack Books Example in JRuby

This is an implementation of the [Ratpack Books Example app](https://github.com/ratpack/example-books)
written in JRuby.

## Setup

This application integrates with [ISBNdb](http://isbndb.com/account/logincreate) and as such you will need to create a free
account and API key in order to run the application successfully.
When you have done this, you can set the environment variable `ISBN_KEY` to the value of your API key.

It also requires a PostgreSQL database, and the `JDBC_DATABASE_URL` environment variable. For a
local server, this can be set to the value: `localhost:5432/jruby-ratpack-books` where the database
name is "jruby-ratpack-books".

## Deploy

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy)
