class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "TrackNight <no-reply@tracknight.app>")
  layout "mailer"
end
