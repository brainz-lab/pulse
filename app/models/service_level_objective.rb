class ServiceLevelObjective < ApplicationRecord
  belongs_to :project

  validates :name, :target_metric, :operator, :threshold, presence: true
  validates :target_metric, inclusion: { in: %w[apdex error_rate p95 p99 availability] }
  validates :operator, inclusion: { in: %w[lt lte gt gte] }
  validates :threshold, numericality: true
  validates :window_days, numericality: { greater_than: 0 }, allow_nil: true

  scope :enabled, -> { where(enabled: true) }
  scope :due_for_calculation, ->(interval = 5.minutes) {
    enabled.where("last_calculated_at IS NULL OR last_calculated_at < ?", interval.ago)
  }
end
