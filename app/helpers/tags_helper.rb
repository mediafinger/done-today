module TagsHelper
  # The tag times report of a period, of everyone or of one member
  def tag_times_path(project, period, member: nil, format: nil)
    tags_path(current_org, project, **period.param, member_id: member&.id, format:)
  end
end
