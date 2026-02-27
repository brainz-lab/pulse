require "rails_helper"

RSpec.describe SqlNormalizer do
  describe ".normalize" do
    it "returns nil for blank input" do
      expect(described_class.normalize(nil)).to be_nil
      expect(described_class.normalize("")).to be_nil
      expect(described_class.normalize("   ")).to be_nil
    end

    it "replaces integer literals with ?" do
      sql = "SELECT * FROM users WHERE id = 123"
      expect(described_class.normalize(sql)).to eq("SELECT * FROM users WHERE id = ?")
    end

    it "replaces float literals with ?" do
      sql = "SELECT * FROM metrics WHERE value > 3.14"
      expect(described_class.normalize(sql)).to eq("SELECT * FROM metrics WHERE value > ?")
    end

    it "replaces single-quoted string literals with ?" do
      sql = "SELECT * FROM users WHERE email = 'user@example.com'"
      expect(described_class.normalize(sql)).to eq("SELECT * FROM users WHERE email = ?")
    end

    it "replaces UUID literals with ?" do
      sql = "SELECT * FROM projects WHERE id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'"
      expect(described_class.normalize(sql)).to eq("SELECT * FROM projects WHERE id = ?")
    end

    it "collapses IN clauses with multiple values" do
      sql = "SELECT * FROM users WHERE id IN (1, 2, 3, 4)"
      expect(described_class.normalize(sql)).to eq("SELECT * FROM users WHERE id IN (?)")
    end

    it "normalizes whitespace" do
      sql = "SELECT  *  FROM   users   WHERE  id  =  1"
      expect(described_class.normalize(sql)).to eq("SELECT * FROM users WHERE id = ?")
    end

    it "handles complex queries with multiple conditions" do
      sql = "SELECT id, name FROM orders WHERE user_id = 42 AND status = 'pending' AND amount > 100.0"
      normalized = described_class.normalize(sql)
      expect(normalized).to eq("SELECT id, name FROM orders WHERE user_id = ? AND status = ? AND amount > ?")
    end

    it "produces the same output for structurally identical queries" do
      sql1 = "SELECT * FROM users WHERE id = 1"
      sql2 = "SELECT * FROM users WHERE id = 99"
      expect(described_class.normalize(sql1)).to eq(described_class.normalize(sql2))
    end
  end

  describe ".fingerprint" do
    it "returns nil for blank input" do
      expect(described_class.fingerprint(nil)).to be_nil
      expect(described_class.fingerprint("")).to be_nil
    end

    it "returns a 16-character hex string" do
      fp = described_class.fingerprint("SELECT * FROM users WHERE id = 1")
      expect(fp).to match(/\A[a-f0-9]{16}\z/)
    end

    it "produces the same fingerprint for structurally identical queries" do
      fp1 = described_class.fingerprint("SELECT * FROM users WHERE id = 1")
      fp2 = described_class.fingerprint("SELECT * FROM users WHERE id = 999")
      expect(fp1).to eq(fp2)
    end

    it "produces different fingerprints for structurally different queries" do
      fp1 = described_class.fingerprint("SELECT * FROM users WHERE id = 1")
      fp2 = described_class.fingerprint("SELECT * FROM orders WHERE id = 1")
      expect(fp1).not_to eq(fp2)
    end
  end
end
