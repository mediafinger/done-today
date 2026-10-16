module UsersHelper
  # [label, IANA identifier], e.g. ["(GMT+00:00) Edinburgh, London", "Europe/London"]
  def time_zone_options
    ActiveSupport::TimeZone.all.group_by { it.tzinfo.identifier }.map do |identifier, zones|
      [ "(GMT#{zones.first.formatted_offset}) #{zones.map(&:name).join(', ')}", identifier ]
    end
  end
end
