class AggregatedMetric < ApplicationRecord
  belongs_to :project

  GRANULARITIES = %w[minute hour day].freeze

  validates :name, presence: true
  validates :bucket, presence: true
  validates :granularity, inclusion: { in: GRANULARITIES }

  scope :for_range, ->(since, until_time = Time.current) {
    where(bucket: since..until_time)
  }

  scope :by_granularity, ->(granularity) {
    where(granularity: granularity)
  }
end
