class Span < ApplicationRecord
  include Timescaledb::Rails::Model

  belongs_to :trace
  belongs_to :project

  KINDS = %w[
    db http cache render job cable custom
    elasticsearch graphql graphql.field
    mongodb mailer redis
    grape grape.render grape.filter grape.format
  ].freeze

  validates :span_id, presence: true
  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :started_at, presence: true

  scope :db_spans, -> { where(kind: 'db') }
  scope :http_spans, -> { where(kind: 'http') }
  scope :cache_spans, -> { where(kind: 'cache') }
  scope :slow, ->(threshold = 100) { where('duration_ms > ?', threshold) }

  before_save :calculate_duration, if: -> { ended_at.present? && duration_ms.nil? }

  # Formatted display
  def display_name
    case kind
    when 'db'
      operation = data['operation'] || 'SQL'
      table = data['table']
      table ? "#{operation} #{table}" : operation
    when 'http'
      "#{data['method']} #{data['url']}"
    when 'cache'
      hit = data['hit'] ? 'HIT' : 'MISS'
      "Cache #{hit}: #{data['key']}"
    when 'render'
      "Render #{data['template']}"
    else
      name
    end
  end

  private

  def calculate_duration
    self.duration_ms = ((ended_at - started_at) * 1000).round(2)
  end
end
