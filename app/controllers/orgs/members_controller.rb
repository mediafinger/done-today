module Orgs
  # Org owners list the members of their org, change their roles, and deactivate
  #   or reactivate them. Deactivating archives the member, their entries stay.
  #
  class MembersController < AppOrgBaseController
    def index
      authorize!(Member, :index?)

      members = current_org.members.includes(:user).order(:name)

      @active_members = members.active
      @archived_members = members.archived
    end

    def update
      change(:updated, roles: params.expect(member: [ roles: [] ]).fetch(:roles).compact_blank)
    end

    def deactivate
      change(:deactivated, archived_at: member.archived_at || Time.current)
    end

    def reactivate
      change(:reactivated, archived_at: nil)
    end

    private

    # another org's member is a 404, a colleague of a non-owner a 403
    def member
      @member ||= authorize!(current_org.members.find(params[:id]), :manage?)
    end

    # the lock keeps two owners from demoting each other at the same time
    def change(done, **attributes)
      saved = current_org.with_lock { member.update(attributes) }

      if saved
        redirect_to after_change_path, notice: t("controllers.members.#{done}", name: member.name)
      else
        redirect_to members_path, alert: member.errors.full_messages.to_sentence
      end
    end

    # an owner who stepped down or deactivated themselves cannot see the list any more
    def after_change_path
      member.id == current_member.id && !member.active_owner? ? root_path : members_path
    end
  end
end
