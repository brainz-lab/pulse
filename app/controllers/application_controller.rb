class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from StandardError do |exception|
    BrainzLab::Reflex.capture(exception, context: { controller: self.class.name, action: action_name })
    BrainzLab::Signal.trigger("app.unhandled_error", severity: :critical, details: { error: exception.message })
    raise exception
  end
end
