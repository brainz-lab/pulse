class Trace < ApplicationRecord
  include Timescaledb::Rails::Model

  self.primary_key = "id"

  belongs_to :project
  has_many :spans, dependent: :destroy

  KINDS = %w[request job custom].freeze

  validates :trace_id, presence: true
  validates :trace_id, uniqueness: true, unless: :skip_uniqueness_validation
  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :started_at, presence: true

  # Skip uniqueness validation when we've already verified trace doesn't exist
  # (e.g., in batch processing where we pre-check existing traces)
  attr_accessor :skip_uniqueness_validation

  scope :requests, -> { where(kind: "request") }
  scope :jobs, -> { where(kind: "job") }
  scope :recent, -> { order(started_at: :desc) }
  scope :slow, ->(threshold = 1000) { where("duration_ms > ?", threshold) }
  scope :errors, -> { where(error: true) }

  before_save :calculate_duration, if: -> { ended_at.present? && duration_ms.nil? }

  def complete!(ended_at: Time.current, error: false, error_class: nil, error_message: nil)
    # Use update_columns to skip callbacks and validations for performance
    # This avoids N+1 queries from individual transactions
    self.ended_at = ended_at
    self.error = error
    self.error_class = error_class
    self.error_message = error_message
    calculate_duration if self.ended_at.present? && self.duration_ms.nil?
    save!
  end

  # Batch complete multiple traces efficiently using raw SQL
  # Accepts array of hashes with :trace and completion attributes
  def self.complete_batch!(completions)
    return if completions.empty?

    # Build a single UPDATE query with CASE expressions for bulk update
    # This avoids N+1 UPDATE queries
    updates = completions.map do |completion|
      trace = completion[:trace]
      ended_at = completion[:ended_at] || Time.current
      duration_ms = ((ended_at - trace.started_at) * 1000).round(2)

      {
        id: trace.id,
        ended_at: ended_at,
        duration_ms: duration_ms,
        error: completion[:error] || false,
        error_class: completion[:error_class],
        error_message: completion[:error_message]
      }
    end

    ids = updates.map { |u| connection.quote(u[:id]) }.join(", ")

    # Build CASE expressions for each column
    sql = <<~SQL
      UPDATE traces SET
        ended_at = CASE id #{updates.map { |u| "WHEN #{connection.quote(u[:id])} THEN #{connection.quote(u[:ended_at])}" }.join(' ')} END,
        duration_ms = CASE id #{updates.map { |u| "WHEN #{connection.quote(u[:id])} THEN #{u[:duration_ms]}" }.join(' ')} END,
        error = CASE id #{updates.map { |u| "WHEN #{connection.quote(u[:id])} THEN #{u[:error]}" }.join(' ')} END,
        error_class = CASE id #{updates.map { |u| "WHEN #{connection.quote(u[:id])} THEN #{connection.quote(u[:error_class])}" }.join(' ')} END,
        error_message = CASE id #{updates.map { |u| "WHEN #{connection.quote(u[:id])} THEN #{connection.quote(u[:error_message])}" }.join(' ')} END,
        updated_at = #{connection.quote(Time.current)}
      WHERE id IN (#{ids})
    SQL

    connection.execute(sql)

    # Update the in-memory objects
    completions.each do |completion|
      trace = completion[:trace]
      update = updates.find { |u| u[:id] == trace.id }
      trace.assign_attributes(
        ended_at: update[:ended_at],
        duration_ms: update[:duration_ms],
        error: update[:error],
        error_class: update[:error_class],
        error_message: update[:error_message]
      )
    end
  end

  def add_span!(attributes)
    span = spans.create!(attributes.merge(project: project))

    # Update aggregate metrics on trace
    recalculate_span_metrics!

    span
  end

  def waterfall
    spans.order(:started_at).map do |span|
      {
        id: span.span_id,
        parent_id: span.parent_span_id,
        name: span.name,
        kind: span.kind,
        started_at: span.started_at,
        duration_ms: span.duration_ms,
        offset_ms: ((span.started_at - started_at) * 1000).round(2),
        data: span.data,
        error: span.error
      }
    end
  end

  def apdex_category(threshold = nil)
    threshold ||= project.apdex_t
    duration_s = duration_ms / 1000.0

    if duration_s <= threshold
      :satisfied
    elsif duration_s <= threshold * 4
      :tolerating
    else
      :frustrated
    end
  end

  private

  def calculate_duration
    self.duration_ms = ((ended_at - started_at) * 1000).round(2)
  end

  def recalculate_span_metrics!
    self.span_count = spans.count
    self.db_duration_ms = spans.where(kind: "db").sum(:duration_ms)
    self.view_duration_ms = spans.where(kind: "render").sum(:duration_ms)
    self.external_duration_ms = spans.where(kind: "http").sum(:duration_ms)
    save!
  end
end
