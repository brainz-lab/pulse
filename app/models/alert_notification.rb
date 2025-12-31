class AlertNotification < ApplicationRecord
  belongs_to :alert
  belongs_to :notification_channel

  STATUSES = %w[pending sent failed].freeze

  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }
  scope :sent, -> { where(status: "sent") }
  scope :failed, -> { where(status: "failed") }

  def pending?
    status == "pending"
  end

  def sent?
    status == "sent"
  end

  def failed?
    status == "failed"
  end

  def mark_sent!
    update!(status: "sent", sent_at: Time.current)
    notification_channel.record_success!
  end

  def mark_failed!(error_message)
    update!(status: "failed", error_message: error_message)
    notification_channel.record_failure!
  end
end
