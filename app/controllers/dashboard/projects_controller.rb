module Dashboard
  class ProjectsController < ApplicationController
    layout 'dashboard'

    def index
      @projects = Project.order(created_at: :desc)
    end
  end
end
