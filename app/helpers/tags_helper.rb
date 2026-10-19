module TagsHelper
  # The tag times report of a period, of everyone or of one member, of a project or the whole org (nil)
  def tag_times_path(project, period, member: nil, format: nil)
    params = { **period.param, member_id: member&.id, format: }

    project ? tags_path(current_org, project, **params) : org_tags_path(current_org, **params)
  end

  # linked to its entries in a project, the org has no such page
  def tag_times_tag(tag, project)
    project ? link_to("##{tag}", tag_path(current_org, project, tag)) : "##{tag}"
  end
end
