class ApdexCalculator
  # Apdex = (Satisfied + Tolerating/2) / Total
  #
  # Satisfied: duration <= T
  # Tolerating: T < duration <= 4T
  # Frustrated: duration > 4T

  def self.calculate(traces:, threshold:)
    total = traces.count
    return 1.0 if total == 0

    threshold_ms = threshold * 1000

    satisfied = traces.where('duration_ms <= ?', threshold_ms).count
    tolerating = traces.where('duration_ms > ? AND duration_ms <= ?', threshold_ms, threshold_ms * 4).count

    ((satisfied + (tolerating / 2.0)) / total).round(2)
  end
end
