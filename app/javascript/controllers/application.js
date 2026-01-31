import { Application } from "@hotwired/stimulus"
import ChartController from "controllers/chart_controller"
import RealtimeMetricsController from "controllers/realtime_metrics_controller"
import DarkModeController from "controllers/dark_mode_controller"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

// Register controllers
application.register("chart", ChartController)
application.register("realtime-metrics", RealtimeMetricsController)
application.register("dark-mode", DarkModeController)

export { application }
