class ParticipantName
  def self.normalize(value)
    value.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace).unicode_normalize(:nfkd)
      .gsub(/\p{Mn}/, "")
      .upcase
      .gsub(/[^A-Z0-9 ]/, " ")
      .squeeze(" ")
      .strip
  end
end