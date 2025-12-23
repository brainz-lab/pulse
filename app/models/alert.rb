class Alert < ApplicationRecord
  belongs_to :project
  belongs_to :alert_rule
  has_many :alert_notifications, dependent: :destroy

  STATUSES = %w[firing resolved].freeze

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :severity, presence: true
  validates :metric_type, presence: true
  validates :operator, presence: true
  validates :threshold, presence: true
  validates :value, presence: true
  validates :triggered_at, presence: true

  scope :firing, -> { where(status: 'firing') }
  scope :resolved, -> { where(status: 'resolved') }
  scope :recent, -> { order(triggered_at: :desc) }
  scope :critical, -> { where(severity: 'critical') }
  scope :warning, -> { where(severity: 'warning') }

  def firing?
    status == 'firing'
  end

  def resolved?
    status == 'resolved'
  end

  def duration
    return nil unless resolved_at
    resolved_at - triggered_at
  end

  def duration_text
    return 'ongoing' if firing?

    seconds = duration.to_i
    if seconds < 60
      "#{seconds}s"
    elsif seconds < 3600
      "#{seconds / 60}m"
    else
      "#{seconds / 3600}h #{(seconds % 3600) / 60}m"
    end
  end

  def severity_color
    case severity
    when 'critical' then '#DC2626'
    when 'warning' then '#F59E0B'
    else '#6B7280'
    end
  end

  def severity_badge_class
    case severity
    when 'critical' then 'bg-red-100 text-red-800'
    when 'warning' then 'bg-amber-100 text-amber-800'
    else 'bg-gray-100 text-gray-800'
    end
  end
end
