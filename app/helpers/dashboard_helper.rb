module DashboardHelper
  def apdex_color(score)
    case score
    when 0.94..1.0 then 'bg-green-500'
    when 0.85..0.94 then 'bg-green-400'
    when 0.70..0.85 then 'bg-yellow-400'
    when 0.50..0.70 then 'bg-orange-500'
    else 'bg-red-500'
    end
  end

  def span_color(kind)
    case kind
    when 'db' then 'bg-purple-400'
    when 'http' then 'bg-blue-400'
    when 'cache' then 'bg-green-400'
    when 'render' then 'bg-orange-400'
    else 'bg-stone-400'
    end
  end

  def span_badge_color(kind)
    case kind
    when 'db' then 'bg-purple-100 text-purple-700'
    when 'http' then 'bg-blue-100 text-blue-700'
    when 'cache' then 'bg-green-100 text-green-700'
    when 'render' then 'bg-orange-100 text-orange-700'
    else 'bg-stone-100 text-stone-700'
    end
  end

  def span_kind_bg(kind)
    case kind
    when 'db' then '#F3E8FF'
    when 'http' then '#DBEAFE'
    when 'cache' then '#DCFCE7'
    when 'render' then '#FFEDD5'
    else '#F0EFED'
    end
  end

  def span_kind_color(kind)
    case kind
    when 'db' then '#7C3AED'
    when 'http' then '#2563EB'
    when 'cache' then '#16A34A'
    when 'render' then '#EA580C'
    else '#6B6760'
    end
  end

  # Dark theme colors for trace view
  def span_kind_dark_color(kind)
    case kind
    when 'db' then '#A78BFA'
    when 'http' then '#60A5FA'
    when 'cache' then '#4ADE80'
    when 'render' then '#FB923C'
    else '#9CA3AF'
    end
  end

  def span_kind_dark_bg(kind)
    case kind
    when 'db' then 'rgba(167, 139, 250, 0.2)'
    when 'http' then 'rgba(96, 165, 250, 0.2)'
    when 'cache' then 'rgba(74, 222, 128, 0.2)'
    when 'render' then 'rgba(251, 146, 60, 0.2)'
    else 'rgba(156, 163, 175, 0.2)'
    end
  end

  # Duration helpers for trace view
  def duration_color(ms)
    return '#6B6760' if ms.nil?
    case ms
    when 0..100 then '#22C55E'
    when 100..300 then '#84CC16'
    when 300..500 then '#EAB308'
    when 500..1000 then '#F97316'
    else '#DC2626'
    end
  end

  def duration_badge_bg(ms)
    return 'rgba(107, 103, 96, 0.2)' if ms.nil?
    case ms
    when 0..100 then 'rgba(34, 197, 94, 0.2)'
    when 100..300 then 'rgba(132, 204, 22, 0.2)'
    when 300..500 then 'rgba(234, 179, 8, 0.2)'
    when 500..1000 then 'rgba(249, 115, 22, 0.2)'
    else 'rgba(220, 38, 38, 0.2)'
    end
  end

  def duration_label(ms)
    return '-' if ms.nil?
    case ms
    when 0..100 then 'FAST'
    when 100..300 then 'OK'
    when 300..500 then 'SLOW'
    when 500..1000 then 'VERY SLOW'
    else 'CRITICAL'
    end
  end
end
