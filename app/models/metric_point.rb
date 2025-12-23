class MetricPoint < ApplicationRecord
  include Timescaledb::Rails::Model

  self.primary_key = "id"

  belongs_to :project
  belongs_to :metric

  validates :timestamp, presence: true
  validates :value, presence: true
end
