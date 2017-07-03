CREATE TABLE books (
  id serial not null PRIMARY KEY,
  isbn varchar(256) not null,
  quantity integer,
  price money,
  title varchar(256),
  author varchar(256),
  publisher varchar(256)
);
