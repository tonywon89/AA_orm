require 'byebug'
require 'singleton'
require 'sqlite3'

class QuestionsDatabase < SQLite3::Database
  include Singleton

  def initialize
    super('questions.db')

    self.results_as_hash = true

    self.type_translation = true
  end
end

class ModelBase
  def self.all(table)
    results = QuestionsDatabase.instance.execute(<<-SQL)
      SELECT
        *
      FROM
        #{table}
    SQL

    results.map { |result| self.new(result) }
  end

  def self.find_by_id(table, id)
    results = QuestionsDatabase.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        #{table}
      WHERE
        id = ?
    SQL

    return "Not found" if results.empty?

    self.new(results.first)
  end

end

class User < ModelBase
  def self.all
    super('users')
  end

  def self.find_by_id(id)
    super('users', id)
  end

  def self.find_by_name(fname, lname)
    user = QuestionsDatabase.instance.execute(<<-SQL, fname, lname)
      SELECT
        *
      FROM
        users
      WHERE
        fname = ? AND lname = ?
    SQL

    return "User not found" if user.empty?

    User.new(user.first)
  end

  attr_accessor :fname, :lname

  def initialize(options = {})
    @id = options['id']
    @fname = options['fname']
    @lname = options['lname']
  end

  def authored_questions
    Question.find_by_author_id(@id)
  end

  def authored_replies
    Reply.find_by_user_id(@id)
  end

  def followed_questions
    QuestionFollow.followed_questions_for_user_id(@id)
  end

  def liked_questions
    QuestionLike.liked_questions_for_user_id(@id)
  end

  def save
    if @id.nil?
      QuestionsDatabase.instance.execute(<<-SQL, @fname, @lname)
        INSERT INTO
          users(fname, lname)
        VALUES
          (?, ?)
      SQL
      @id = QuestionsDatabase.instance.last_insert_row_id
    else
      QuestionsDatabase.instance.execute(<<-SQL, fname: @fname, lname: @lname, id: @id)
        UPDATE
          users
        SET
          fname = :fname,
          lname = :lname
        WHERE
          id = :id
      SQL
    end
    self
  end

  def average_karma
    results = QuestionsDatabase.instance.execute(<<-SQL, @id)
      SELECT
        CAST(COUNT(DISTINCT questions.id) AS FLOAT) AS questions, COUNT(question_likes.user_id) AS karma
      FROM
        questions
      LEFT OUTER JOIN
        question_likes ON questions.id = question_likes.question_id
      WHERE
        author_id = ?
    SQL
    results.first['karma'] / results.first['questions']
  end
end

class Question < ModelBase
  def self.all
    super('questions')
  end

  def self.find_by_id(id)
    super('questions', id)
  end

  def self.find_by_author_id(author_id)
    questions = QuestionsDatabase.instance.execute('SELECT * FROM questions WHERE author_id = ?', author_id)

    questions.map{ |question| Question.new(question) }
  end

  def self.most_followed(n)
    QuestionFollow.most_followed_questions(n)
  end

  attr_accessor :title, :body

  def initialize(options = {})
    @id = options['id']
    @title = options['title']
    @body = options['body']
    @author_id = options['author_id']
  end

  def author
    User.find_by_id(@author_id)
  end

  def replies
    Reply.find_by_question_id(@id)
  end

  def followers
    QuestionFollow.followers_for_question_id(@id)
  end

  def likers
    QuestionLike.likers_for_question_id(@id)
  end

  def num_likes
    QuestionLike.num_likes_for_question_id(@id)
  end

  def most_liked(n)
    QuestionLike.most_liked_questions(n)
  end

  def save
    if @id.nil?
      QuestionsDatabase.instance.execute(<<-SQL, title: @title, body: @body, author_id: @author_id)
        INSERT INTO
          questions(title, body, author_id)
        VALUES
          (:title, :body, :author_id)
      SQL
      @id = QuestionsDatabase.instance.last_insert_row_id
    else
      QuestionsDatabase.instance.execute(<<-SQL, title: @title, body: @body, author_id: @author_id, id: @id)
        UPDATE
          questions
        SET
          title = :title,
          body = :body,
          author_id = :author_id
        WHERE
          id = :id
      SQL
    end
    self
  end
end

class Reply < ModelBase
  def self.all
    super('replies')
  end


  def self.find_by_id(id)
    super('replies', id)
  end

  def self.find_by_user_id(user_id)
    replies = QuestionsDatabase.instance.execute('SELECT * FROM replies WHERE user_id = ?', user_id)

    replies.map{ |reply| Reply.new(reply) }
  end

  def self.find_by_question_id(question_id)
    replies = QuestionsDatabase.instance.execute('SELECT * FROM replies WHERE question_id = ?', question_id)

    replies.map { |reply| Reply.new(reply) }
  end

  attr_accessor :body
  attr_reader :id

  def initialize(options = {})
    @id = options['id']
    @body = options['body']
    @parent_id = options['parent_id']
    @question_id = options['question_id']
    @user_id = options['user_id']
  end

  def author
    User.find_by_id(@user_id)
  end

  def question
    Question.find_by_id(@question_id)
  end

  def parent_reply
    Reply.find_by_id(@parent_id)
  end

  def child_replies
    children = []
    question.replies.each do |reply|
      children << reply if !reply.parent_reply.is_a?(String) && reply.parent_reply.id == @id
    end
    children
  end

  def save
    options =  {body: @body, parent_id: @parent_id, question_id: @question_id, user_id: @user_id }
    if @id.nil?
      QuestionsDatabase.instance.execute(<<-SQL, options)
        INSERT INTO
          replies (body, parent_id, question_id, user_id)
        VALUES
          (:body, :parent_id, :question_id, :user_id)
      SQL
      @id = QuestionsDatabase.instance.last_insert_row_id
    else
      options = options.merge({id: @id})

      QuestionsDatabase.instance.execute(<<-SQL, options)
        UPDATE
          replies
        SET
          body = :body,
          parent_id = :parent_id,
          question_id = :question_id,
          user_id = :user_id
        WHERE
          id = :id
      SQL
    end
    self
  end

end

class QuestionFollow
  def self.all
    results = QuestionsDatabase.instance.execute('SELECT * FROM question_follows')
    results.map{ |result| QuestionFollow.new(result) }
  end

  def self.followers_for_question_id(question_id)
    results = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        users.id, users.fname, users.lname
      FROM
        question_follows
      JOIN
        users ON question_follows.user_id = users.id
      WHERE
        question_id = ?
    SQL

    results.map{ |result| User.new(result) }
  end

  def self.followed_questions_for_user_id(user_id)
    results = QuestionsDatabase.instance.execute(<<-SQL, user_id)
      SELECT
        questions.id, questions.title, questions.body, questions.author_id
      FROM
        question_follows
      JOIN
        questions ON question_follows.question_id = questions.id
      WHERE
        user_id = ?
    SQL

    results.map { |result| Question.new(result) }
  end

  def self.most_followed_questions(n)
    results = QuestionsDatabase.instance.execute(<<-SQL, n)
      SELECT
        questions.id, questions.title, questions.body, questions.author_id
      FROM
        questions
      LEFT OUTER JOIN
        question_follows ON questions.id = question_follows.question_id
      GROUP BY
        id
      ORDER BY
        COUNT(question_follows.question_id) DESC
      LIMIT
        ?
    SQL
    results.map { |result| Question.new(result) }

  end

  def initialize(options = {})
    @question_id = options['question_id']
    @user_id = options['user_id']
  end

end

class QuestionLike

  def self.all
    results = QuestionsDatabase.instance.execute('SELECT * FROM question_likes')
    results.map{ |result| QuestionLike.new(result) }
  end

  def self.likers_for_question_id(question_id)
    results = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        users.id, users.fname, users.lname
      FROM
        question_likes
      JOIN
        users ON users.id = question_likes.user_id
      WHERE
        question_id = ?
    SQL
    results.map { |result| User.new(result) }
  end

  def self.num_likes_for_question_id(question_id)
    result = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        COUNT(*) AS count
      FROM
        question_likes
      WHERE
        question_id = ?
    SQL
    result.first['count']
  end

  def self.liked_questions_for_user_id(user_id)
    results = QuestionsDatabase.instance.execute(<<-SQL, user_id)
      SELECT
        questions.id, questions.title, questions.body, questions.author_id
      FROM
        question_likes
      JOIN
        questions ON questions.id = question_likes.question_id
      WHERE
        user_id = ?
    SQL

    results.map { |result| Question.new(result) }
  end

  def self.most_liked_questions(n)
    results = QuestionsDatabase.instance.execute(<<-SQL, n)
      SELECT
        questions.id, questions.title, questions.body, questions.author_id
      FROM
        questions
      LEFT OUTER JOIN
        question_likes ON questions.id = question_likes.question_id
      GROUP BY
        id
      ORDER BY
        COUNT(question_likes.question_id) DESC
      LIMIT
        ?
    SQL

    results.map{ |result| Question.new(result) }
  end

  def initialize(options = {})
    @question_id = options['question_id']
    @user_id = options['user_id']
  end

end
