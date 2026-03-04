class SavedView < ApplicationRecord
  belongs_to :project

  validates :name, :view_type, presence: true
  validates :view_type, inclusion: { in: %w[requests endpoints queries overview] }

  scope :pinned, -> { where(pinned: true) }
  scope :for_type, ->(type) { where(view_type: type) }
end
