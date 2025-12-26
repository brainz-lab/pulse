require "test_helper"

class SqlNormalizerTest < ActiveSupport::TestCase
  test "normalize should handle nil input" do
    assert_nil SqlNormalizer.normalize(nil)
  end

  test "normalize should handle empty string" do
    assert_nil SqlNormalizer.normalize("")
  end

  test "normalize should replace numeric literals" do
    sql = "SELECT * FROM users WHERE id = 123"
    normalized = SqlNormalizer.normalize(sql)
    assert_equal "SELECT * FROM users WHERE id = ?", normalized
  end

  test "normalize should replace decimal numbers" do
    sql = "SELECT * FROM products WHERE price > 19.99"
    normalized = SqlNormalizer.normalize(sql)
    assert_equal "SELECT * FROM products WHERE price > ?", normalized
  end

  test "normalize should replace single-quoted strings" do
    sql = "SELECT * FROM users WHERE name = 'John'"
    normalized = SqlNormalizer.normalize(sql)
    assert_equal "SELECT * FROM users WHERE name = ?", normalized
  end

  test "normalize should replace double-quoted strings" do
    sql = 'SELECT * FROM users WHERE email = "test@example.com"'
    normalized = SqlNormalizer.normalize(sql)
    assert_equal "SELECT * FROM users WHERE email = ?", normalized
  end

  test "normalize should replace UUIDs" do
    uuid = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
    sql = "SELECT * FROM resources WHERE uuid = '#{uuid}'"
    normalized = SqlNormalizer.normalize(sql)
    assert_equal "SELECT * FROM resources WHERE uuid = ?", normalized
  end

  test "normalize should collapse IN clauses" do
    sql = "SELECT * FROM users WHERE id IN (1, 2, 3, 4, 5)"
    normalized = SqlNormalizer.normalize(sql)
    assert_equal "SELECT * FROM users WHERE id IN (?)", normalized
  end

  test "normalize should collapse IN clauses with strings" do
    sql = "SELECT * FROM users WHERE status IN ('active', 'pending', 'approved')"
    normalized = SqlNormalizer.normalize(sql)
    assert_equal "SELECT * FROM users WHERE status IN (?)", normalized
  end

  test "normalize should normalize whitespace" do
    sql = "SELECT  *   FROM   users   WHERE  id = 123"
    normalized = SqlNormalizer.normalize(sql)
    assert_equal "SELECT * FROM users WHERE id = ?", normalized
  end

  test "normalize should handle complex queries" do
    sql = <<~SQL
      SELECT users.*, posts.title
      FROM users
      INNER JOIN posts ON posts.user_id = users.id
      WHERE users.id = 123
        AND posts.created_at > '2024-01-01'
        AND posts.status IN ('published', 'draft')
      LIMIT 10
    SQL

    normalized = SqlNormalizer.normalize(sql)
    expected = "SELECT users.*, posts.title FROM users INNER JOIN posts ON posts.user_id = users.id WHERE users.id = ? AND posts.created_at > ? AND posts.status IN (?) LIMIT ?"

    assert_equal expected, normalized
  end

  test "normalize should preserve table and column names" do
    sql = "SELECT user_123.name FROM user_123 WHERE user_123.id = 456"
    normalized = SqlNormalizer.normalize(sql)
    # Numbers in identifiers should be preserved
    assert_includes normalized, "user_"
  end

  test "normalize should handle UPDATE statements" do
    sql = "UPDATE users SET name = 'Alice', age = 30 WHERE id = 5"
    normalized = SqlNormalizer.normalize(sql)
    assert_equal "UPDATE users SET name = ?, age = ? WHERE id = ?", normalized
  end

  test "normalize should handle INSERT statements" do
    sql = "INSERT INTO users (name, email, age) VALUES ('Bob', 'bob@example.com', 25)"
    normalized = SqlNormalizer.normalize(sql)
    assert_equal "INSERT INTO users (name, email, age) VALUES (?, ?, ?)", normalized
  end

  test "normalize should handle DELETE statements" do
    sql = "DELETE FROM users WHERE id = 999"
    normalized = SqlNormalizer.normalize(sql)
    assert_equal "DELETE FROM users WHERE id = ?", normalized
  end

  test "normalize should be case insensitive for IN clauses" do
    sql = "SELECT * FROM users WHERE id in (1, 2, 3)"
    normalized = SqlNormalizer.normalize(sql)
    assert_equal "SELECT * FROM users WHERE id in (?)", normalized
  end

  test "fingerprint should return MD5 hash of normalized SQL" do
    sql = "SELECT * FROM users WHERE id = 123"
    fingerprint = SqlNormalizer.fingerprint(sql)

    assert_not_nil fingerprint
    assert_equal 16, fingerprint.length
    assert_match /^[a-f0-9]+$/, fingerprint
  end

  test "fingerprint should return same hash for equivalent queries" do
    sql1 = "SELECT * FROM users WHERE id = 123"
    sql2 = "SELECT * FROM users WHERE id = 456"

    fingerprint1 = SqlNormalizer.fingerprint(sql1)
    fingerprint2 = SqlNormalizer.fingerprint(sql2)

    assert_equal fingerprint1, fingerprint2
  end

  test "fingerprint should return different hash for different queries" do
    sql1 = "SELECT * FROM users WHERE id = 123"
    sql2 = "SELECT * FROM posts WHERE id = 123"

    fingerprint1 = SqlNormalizer.fingerprint(sql1)
    fingerprint2 = SqlNormalizer.fingerprint(sql2)

    assert_not_equal fingerprint1, fingerprint2
  end

  test "fingerprint should handle nil input" do
    assert_nil SqlNormalizer.fingerprint(nil)
  end

  test "fingerprint should ignore whitespace differences" do
    sql1 = "SELECT * FROM users WHERE id = 123"
    sql2 = "SELECT  *  FROM  users  WHERE  id = 456"

    fingerprint1 = SqlNormalizer.fingerprint(sql1)
    fingerprint2 = SqlNormalizer.fingerprint(sql2)

    assert_equal fingerprint1, fingerprint2
  end

  test "normalize should handle LIKE patterns" do
    sql = "SELECT * FROM users WHERE name LIKE '%john%'"
    normalized = SqlNormalizer.normalize(sql)
    assert_equal "SELECT * FROM users WHERE name LIKE ?", normalized
  end

  test "normalize should handle negative numbers" do
    sql = "SELECT * FROM accounts WHERE balance < -100"
    normalized = SqlNormalizer.normalize(sql)
    assert_equal "SELECT * FROM accounts WHERE balance < -?", normalized
  end

  test "normalize should handle scientific notation" do
    sql = "SELECT * FROM measurements WHERE value > 1.5e10"
    normalized = SqlNormalizer.normalize(sql)
    assert_includes normalized, "?"
  end
end
