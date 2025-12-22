class MetricPoint < ApplicationRecord
  belongs_to :project
  belongs_to :metric

  validates :timestamp, presence: true
  validates :value, presence: true
end
