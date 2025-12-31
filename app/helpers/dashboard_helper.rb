# frozen_string_literal: true

module DashboardHelper
  # Icon helpers - inline SVG to avoid partial render overhead
  ICONS = {
    overview: '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"/></svg>',
    requests: '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4"/></svg>',
    jobs: '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/></svg>',
    endpoints: '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/></svg>',
    queries: '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4m0 5c0 2.21-3.582 4-8 4s-8-1.79-8-4"/></svg>',
    metrics: '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/></svg>',
    alerts: '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"/></svg>',
    dev_tools: '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/></svg>'
  }.freeze

  def icon(name)
    ICONS[name.to_sym]&.html_safe
  end

  # Navigation helpers for sidebar
  def nav_active?(controller_or_controllers)
    controllers = Array(controller_or_controllers).map(&:to_s)
    controllers.include?(controller_name)
  end

  def nav_link_class(controller_or_controllers)
    nav_active?(controller_or_controllers) ? "nav-item active" : "nav-item"
  end

  def apdex_color(score)
    case score
    when 0.94..1.0 then "bg-green-500"
    when 0.85..0.94 then "bg-green-400"
    when 0.70..0.85 then "bg-yellow-400"
    when 0.50..0.70 then "bg-orange-500"
    else "bg-red-500"
    end
  end

  def span_color(kind)
    case kind
    when "db" then "bg-purple-400"
    when "http" then "bg-blue-400"
    when "cache" then "bg-green-400"
    when "render" then "bg-orange-400"
    else "bg-stone-400"
    end
  end

  def span_badge_color(kind)
    case kind
    when "db" then "bg-purple-100 text-purple-700"
    when "http" then "bg-blue-100 text-blue-700"
    when "cache" then "bg-green-100 text-green-700"
    when "render" then "bg-orange-100 text-orange-700"
    else "bg-stone-100 text-stone-700"
    end
  end

  def span_kind_bg(kind)
    case kind
    when "db" then "#F3E8FF"
    when "http" then "#DBEAFE"
    when "cache" then "#DCFCE7"
    when "render" then "#FFEDD5"
    else "#F0EFED"
    end
  end

  def span_kind_color(kind)
    case kind
    when "db" then "#7C3AED"
    when "http" then "#2563EB"
    when "cache" then "#16A34A"
    when "render" then "#EA580C"
    else "#6B6760"
    end
  end

  # Dark theme colors for trace view
  def span_kind_dark_color(kind)
    case kind
    when "db" then "#A78BFA"
    when "http" then "#60A5FA"
    when "cache" then "#4ADE80"
    when "render" then "#FB923C"
    else "#9CA3AF"
    end
  end

  def span_kind_dark_bg(kind)
    case kind
    when "db" then "rgba(167, 139, 250, 0.2)"
    when "http" then "rgba(96, 165, 250, 0.2)"
    when "cache" then "rgba(74, 222, 128, 0.2)"
    when "render" then "rgba(251, 146, 60, 0.2)"
    else "rgba(156, 163, 175, 0.2)"
    end
  end

  # Duration helpers for trace view
  def duration_color(ms)
    return "#6B6760" if ms.nil?
    case ms
    when 0..100 then "#22C55E"
    when 100..300 then "#84CC16"
    when 300..500 then "#EAB308"
    when 500..1000 then "#F97316"
    else "#DC2626"
    end
  end

  def duration_badge_bg(ms)
    return "rgba(107, 103, 96, 0.2)" if ms.nil?
    case ms
    when 0..100 then "rgba(34, 197, 94, 0.2)"
    when 100..300 then "rgba(132, 204, 22, 0.2)"
    when 300..500 then "rgba(234, 179, 8, 0.2)"
    when 500..1000 then "rgba(249, 115, 22, 0.2)"
    else "rgba(220, 38, 38, 0.2)"
    end
  end

  def duration_label(ms)
    return "-" if ms.nil?
    case ms
    when 0..100 then "FAST"
    when 100..300 then "OK"
    when 300..500 then "SLOW"
    when 500..1000 then "VERY SLOW"
    else "CRITICAL"
    end
  end
end
