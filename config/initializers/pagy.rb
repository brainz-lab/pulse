# frozen_string_literal: true

require "pagy/extras/overflow"
require "pagy/extras/countless"

Pagy::DEFAULT[:limit] = 25
Pagy::DEFAULT[:overflow] = :last_page
