class Trace < ApplicationRecord
  include Timescaledb::Rails::Model

  belongs_to :project
  has_many :spans, dependent: :destroy

  KINDS = %w[request job custom].freeze

  validates :trace_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :started_at, presence: true

  scope :requests, -> { where(kind: 'request') }
  scope :jobs, -> { where(kind: 'job') }
  scope :recent, -> { order(started_at: :desc) }
  scope :slow, ->(threshold = 1000) { where('duration_ms > ?', threshold) }
  scope :errors, -> { where(error: true) }

  before_save :calculate_duration, if: -> { ended_at.present? && duration_ms.nil? }

  def complete!(ended_at: Time.current, error: false, error_class: nil, error_message: nil)
    update!(
      ended_at: ended_at,
      error: error,
      error_class: error_class,
      error_message: error_message
    )
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
    self.db_duration_ms = spans.where(kind: 'db').sum(:duration_ms)
    self.view_duration_ms = spans.where(kind: 'render').sum(:duration_ms)
    self.external_duration_ms = spans.where(kind: 'http').sum(:duration_ms)
    save!
  end
end
