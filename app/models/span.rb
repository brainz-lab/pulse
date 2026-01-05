class Span < ApplicationRecord
  include Timescaledb::Rails::Model

  self.primary_key = "id"

  belongs_to :trace
  belongs_to :project

  KINDS = %w[
    db db.sql
    http http.request http.response http.redirect http.middleware http.dispatch http.file http.callback
    cache cache.read cache.write cache.delete cache.fragment
    render view
    job job.enqueue job.perform job.retry job.discard
    cable cable.connect cable.disconnect cable.transmit
    custom
    elasticsearch graphql graphql.field
    mongodb mailer redis
    grape grape.render grape.filter grape.format
    security.params
    browser browser.lcp browser.fcp browser.ttfb browser.fid browser.inp browser.cls browser.network browser.resource
  ].freeze

  validates :span_id, presence: true
  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :started_at, presence: true

  scope :db_spans, -> { where(kind: "db") }
  scope :http_spans, -> { where(kind: "http") }
  scope :cache_spans, -> { where(kind: "cache") }
  scope :browser_spans, -> { where("kind LIKE 'browser%'") }
  scope :slow, ->(threshold = 100) { where("duration_ms > ?", threshold) }

  before_save :calculate_duration, if: -> { ended_at.present? && duration_ms.nil? }

  # Formatted display
  def display_name
    case kind
    when "db"
      operation = data["operation"] || "SQL"
      table = data["table"]
      table ? "#{operation} #{table}" : operation
    when "http"
      "#{data['method']} #{data['url']}"
    when "cache"
      hit = data["hit"] ? "HIT" : "MISS"
      "Cache #{hit}: #{data['key']}"
    when "render"
      "Render #{data['template']}"
    when "browser.lcp"
      "LCP: #{duration_ms.round(0)}ms (#{data['rating']})"
    when "browser.fcp"
      "FCP: #{duration_ms.round(0)}ms (#{data['rating']})"
    when "browser.ttfb"
      "TTFB: #{duration_ms.round(0)}ms (#{data['rating']})"
    when "browser.fid"
      "FID: #{duration_ms.round(0)}ms (#{data['rating']})"
    when "browser.inp"
      "INP: #{duration_ms.round(0)}ms (#{data['rating']})"
    when "browser.cls"
      "CLS: #{duration_ms.round(4)} (#{data['rating']})"
    when "browser.network"
      "Browser: #{data['method']} #{data['path']} (#{data['status']})"
    when "browser.resource"
      "Resource: #{data['resource_name']}"
    else
      name
    end
  end

  private

  def calculate_duration
    self.duration_ms = ((ended_at - started_at) * 1000).round(2)
  end
end
