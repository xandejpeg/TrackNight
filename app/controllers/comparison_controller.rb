class ComparisonController < ApplicationController
  def show
    @acf = PerformanceStats.new(profile_code: "ACF")
    @ac = PerformanceStats.new(profile_code: "AC")
  end
end
