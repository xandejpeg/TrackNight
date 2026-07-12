class TimelineController < ApplicationController
  def show
    @stats = stats_for_current_profile
    # Mais recentes primeiro na linha do tempo
    @sessions = @stats.sessions.reverse
    @record_fields = @sessions.each_with_object({}) do |s, acc|
      entry = s.alessandro_entry
      acc[s.id] = entry ? @stats.record_breaking_fields(entry) : []
    end
  end
end
