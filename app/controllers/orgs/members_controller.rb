module Orgs
  # Internals list the members of their org, guests apart. Org managers and owners change
  #   their role, and deactivate or reactivate them, only owners touch owners.
  #   Deactivating archives the member, their entries stay.
  #
  class MembersController < AppOrgBaseController
    # members are looked up in current_org, only internals get here
    skip_verify_authorized_scoped

    def index
      authorize!

      members = current_org.members.includes(:user).order(:name)

      @active_members = members.active.internal
      @guests = members.active.guests.includes(participations: :project)
      @can_manage = allowed_to?(:manage?, Member)
      return unless @can_manage

      @archived_members = members.archived
      @invitations = current_org.invitations.pending.includes(:invited_by, :project).order(:email)
    end

    def update
      role = params.expect(member: [ :role ]).fetch(:role)
      authorize! member, to: :grant_owner? if role == "owner"

      change(:updated, role:)
    end

    def deactivate
      change(:deactivated, archived_at: member.archived_at || Time.current)
    end

    def reactivate
      change(:reactivated, archived_at: nil)
    end

    private

    # another org's member is a 404, a colleague of a non-manager or an owner of a manager a 403
    def member
      @member ||= authorize! current_org.members.find(params[:id])
    end

    # the lock keeps two owners from demoting each other at the same time
    def change(done, **attributes)
      saved = current_org.with_lock { member.update(attributes) }

      if saved
        redirect_to after_change_path, notice: t("controllers.members.#{done}", name: member.name)
      else
        redirect_to members_path(current_org), alert: member.errors.full_messages.to_sentence
      end
    end

    # a manager or owner who stepped down or deactivated themselves cannot manage the list any more
    def after_change_path
      member.id == current_member.id && (member.archived? || !member.managing?) ? root_path : members_path(current_org)
    end
  end
end
