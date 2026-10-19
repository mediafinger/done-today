# The time each tag took in a set of entries, for reports: per tag and per member,
#   summed in SQL from what EntryLog#timed_tag stored. Tag times never feed the day
#   total (TimeSummary).
#
#   TagTimes.new(entries).rows.first # => Row(tag: "call", minutes: 190, members: [[anna, 150], [bert, 40]])
#
class TagTimes
  # `members` holds [member, minutes] pairs, ordered by name
  Row = Data.define(:tag, :minutes, :members)

  def initialize(entries)
    @entries = entries
  end

  # Alphabetical by tag. Archived members are included, their time was logged.
  def rows
    @rows ||= sums.group_by { |(tag, _member_id), _minutes| tag }.sort_by(&:first).map do |tag, pairs|
      by_member = pairs.map { |(_tag, member_id), minutes| [ members.fetch(member_id), minutes ] }
        .sort_by { |member, _minutes| member.name.downcase }

      Row.new(tag:, minutes: by_member.sum(&:last), members: by_member)
    end
  end

  private

  attr_reader :entries

  # { [tag, member_id] => minutes }
  def sums
    @sums ||= entries.where.not(timed_tag: nil).group(:timed_tag, :member_id).sum(:duration_minutes)
  end

  def members
    @members ||= Member.where(id: sums.keys.map(&:last).uniq).index_by(&:id)
  end
end
