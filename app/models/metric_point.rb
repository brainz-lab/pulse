class MetricPoint < ApplicationRecord
  include Timescaledb::Rails::Model

  belongs_to :project
  belongs_to :metric

  validates :timestamp, presence: true
  validates :value, presence: true
end
