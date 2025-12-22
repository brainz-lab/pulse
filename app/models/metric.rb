class Metric < ApplicationRecord
  belongs_to :project
  has_many :points, class_name: 'MetricPoint', dependent: :destroy

  KINDS = %w[gauge counter histogram].freeze

  validates :name, presence: true, uniqueness: { scope: :project_id }
  validates :kind, inclusion: { in: KINDS }

  def record!(value, tags: {}, timestamp: Time.current)
    points.create!(
      project: project,
      timestamp: timestamp,
      value: value,
      tags: self.tags.merge(tags)
    )
  end

  def stats(since: 1.hour.ago, granularity: :minute)
    points
      .where('timestamp >= ?', since)
      .group("date_trunc('#{granularity}', timestamp)")
      .select(
        "date_trunc('#{granularity}', timestamp) as bucket",
        'COUNT(*) as count',
        'AVG(value) as avg',
        'MIN(value) as min',
        'MAX(value) as max',
        'SUM(value) as sum'
      )
      .order('bucket')
  end
end
