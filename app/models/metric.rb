class Metric < ApplicationRecord
  belongs_to :project
  has_many :points, class_name: "MetricPoint", dependent: :destroy

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
    scoped = points.where("timestamp >= ?", since)

    aggregates = scoped.pick(
      Arel.sql("AVG(value)"),
      Arel.sql("MIN(value)"),
      Arel.sql("MAX(value)"),
      Arel.sql("COUNT(*)"),
      Arel.sql("(ARRAY_AGG(value ORDER BY timestamp DESC))[1]")
    ) || [nil, nil, nil, 0, nil]

    buckets = scoped
      .group("date_trunc('#{granularity}', timestamp)")
      .select(
        "date_trunc('#{granularity}', timestamp) as bucket",
        "AVG(value) as avg"
      )
      .order("bucket")

    chart_data = buckets.map { |b| { label: b.bucket.strftime("%H:%M"), value: b.avg.to_f } }

    {
      current: aggregates[4]&.to_f,
      avg: aggregates[0]&.to_f,
      min: aggregates[1]&.to_f,
      max: aggregates[2]&.to_f,
      count: aggregates[3].to_i,
      chart_data: chart_data
    }
  end
end
