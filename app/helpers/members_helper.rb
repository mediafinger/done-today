# Members (internal) and guests (external) side by side.
#
module MembersHelper
  # a project an internal knows of but may not read
  def join_project_hint(project)
    leads = project.participants.select { it.lead? && !it.member.archived? }.map { it.member.name }.sort

    leads.any? ? "ask #{leads.to_sentence(last_word_connector: " or ", two_words_connector: " or ")} to join" : "ask an org manager or owner to join"
  end

  # only owners give the owner role
  def assignable_org_roles(roles)
    allowed_to?(:grant_owner?, Member) ? roles : roles - %w[owner]
  end

  # guests never lead a project
  def participant_roles_for(member)
    member.guest? ? Participant::GUEST_ROLES : Participant::VALID_ROLES
  end

  def invitation_role(invitation, with_project_role: true)
    return invitation.role unless invitation.guest?

    "guest in #{invitation.project.name}#{" (#{invitation.project_role})" if with_project_role}"
  end

  # options for grouped_options_for_select, empty groups left out
  def participant_candidates(members)
    { "Members" => members.reject(&:guest?), "Guests (external)" => members.select(&:guest?) }
      .transform_values { |group| group.map { [ it.name, it.id ] } }
      .reject { |_, options| options.empty? }
  end
end
