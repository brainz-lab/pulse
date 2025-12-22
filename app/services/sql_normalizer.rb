class SqlNormalizer
  # Normalizes SQL by replacing literals with placeholders
  # "SELECT * FROM users WHERE id = 123" -> "SELECT * FROM users WHERE id = ?"
  # "SELECT * FROM posts WHERE user_id IN (1,2,3)" -> "SELECT * FROM posts WHERE user_id IN (?)"

  def self.normalize(sql)
    return nil if sql.blank?

    normalized = sql.dup

    # Replace UUID patterns first (before numeric)
    normalized.gsub!(/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/i, '?')

    # Replace string literals (single and double quoted)
    normalized.gsub!(/'[^']*'/, '?')
    normalized.gsub!(/"[^"]*"/, '?')

    # Replace numeric literals (but not table/column names)
    normalized.gsub!(/\b\d+\.?\d*\b/, '?')

    # Collapse IN clauses with multiple placeholders
    normalized.gsub!(/IN\s*\(\s*\?(?:\s*,\s*\?)*\s*\)/i, 'IN (?)')

    # Normalize whitespace
    normalized.squish
  end

  # Generate a fingerprint hash for the normalized SQL
  def self.fingerprint(sql)
    normalized = normalize(sql)
    return nil if normalized.nil?

    Digest::MD5.hexdigest(normalized)[0..15]
  end
end
