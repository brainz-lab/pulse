class Deploy < ApplicationRecord
  belongs_to :project

  validates :version, :deployed_at, presence: true

  scope :recent, -> { order(deployed_at: :desc) }
  scope :since, ->(time) { where("deployed_at >= ?", time) }
end
