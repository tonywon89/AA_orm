DROP TABLE IF EXISTS users;

CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  fname VARCHAR(255) NOT NULL,
  lname VARCHAR(255) NOT NULL
);

DROP TABLE IF EXISTS questions;

CREATE TABLE questions (
  id INTEGER PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  body TEXT NOT NULL,
  author_id INTEGER NOT NULL,

  FOREIGN KEY (author_id) REFERENCES users(id)
);

DROP TABLE IF EXISTS question_follows;

CREATE TABLE question_follows (
  question_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,

  FOREIGN KEY (question_id) REFERENCES questions(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

DROP TABLE IF EXISTS replies;

CREATE TABLE replies (
  id INTEGER PRIMARY KEY,
  body TEXT NOT NULL,
  question_id INTEGER NOT NULL,
  parent_id INTEGER,
  user_id INTEGER NOT NULL,

  FOREIGN KEY (question_id) REFERENCES questions(id),
  FOREIGN KEY (parent_id) REFERENCES replies(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

INSERT INTO
  users  (fname, lname)
VALUES
  ('Tony', 'Won'), ('Eric', 'Lee');

INSERT INTO
  questions  (title, body, author_id)
VALUES
  ('Math Question', 'What is one plus one?', (SELECT id FROM users WHERE fname = 'Tony')),
  ('English Question', 'Wat?', (SELECT id FROM users WHERE fname = 'Tony'));

INSERT INTO
  replies (body, question_id, parent_id, user_id)
VALUES
  ('Two', (SELECT id FROM questions WHERE body = 'What is one plus one?'),
   NULL, (SELECT id FROM users WHERE fname = 'Eric')),
  ('Thanks', (SELECT id FROM questions WHERE body = 'What is one plus one?'),
   1, (SELECT id FROM users WHERE fname = 'Tony'));
