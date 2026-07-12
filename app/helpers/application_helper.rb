module ApplicationHelper
  def lap(ms)
    LapTime.format(ms)
  end

  def lap_delta(ms)
    LapTime.format_delta(ms)
  end

  def duration_human(ms)
    return "—" if ms.nil? || ms.zero?
    total_seconds = ms / 1000
    hours, rest = total_seconds.divmod(3600)
    minutes, seconds = rest.divmod(60)
    hours.positive? ? "#{hours}h #{minutes}min" : "#{minutes}min #{seconds}s"
  end

  def session_date_label(session)
    return "Data pendente" if session.date_pending? || session.started_at.nil?
    session.started_at.strftime("%d/%m/%Y · %H:%M")
  end

  def profile_badge(profile)
    return "".html_safe unless profile
    tag.span(profile.display_name,
      class: "profile-chip",
      style: "--chip-color: #{profile.color}")
  end

  def record_badge(label)
    tag.span(class: "record-badge") do
      safe_join([ tag.span("◆", class: "text-[9px]"), " NOVO RECORDE #{label}" ])
    end
  end

  # Chips de condições: dia/noite (automático) + temperatura + clima (informados)
  def weather_chips(session)
    chips = []
    if session.day_night
      chips << tag.span(session.day? ? "🌞 Dia" : "🌙 Noite", class: "weather-chip")
    end
    chips << tag.span("#{session.track_temp_icon} #{session.track_temp_label}", class: "weather-chip") if session.track_temp
    chips << tag.span("#{session.weather_icon} #{session.weather_label}", class: "weather-chip") if session.weather_condition
    return tag.span("—", class: "text-mute text-[11px]") if chips.empty?
    tag.span(safe_join(chips), class: "inline-flex flex-wrap gap-1")
  end

  def field_record_label(field)
    { best_lap_ms: "VOLTA", s1_ms: "S1", s2_ms: "S2", s3_ms: "S3" }[field]
  end

  def nav_link(label, path, active:)
    link_to label, path,
      class: "nav-link #{'nav-link-active' if active}"
  end
end
