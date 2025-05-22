module Orgs
  class MembersController < ApplicationController
    #
    # TODO: before_action :authenticate_owner!, except: [:index]
    #
    def index
      # TODO: list all members of the organization
    end

    def create
      # TODO: add member to organization / status: invited?! (or unarchive member)
    end

    # TODO: add or remove member roles
    def update
      member = current_org.members.find(update_params[:member_id])

      invalid_roles = update_params[:roles] - Member::VALID_ROLES

      if invalid_roles.any?
        @error_message =
          "Member #{member.name} could not be updated to #{update_params[:roles].join(', ')}, " \
          "as it contains the invalid_roles: #{invalid_roles.join(', ')}"

      # render error
      else
        member = update_roles(member, update_params[:roles])

        # member.save and render success (or failure)
      end
    end

    def destroy
      # TODO: remove member from organization / archive member!
    end

    private

    def update_roles(member, new_roles)
      roles_to_remove = Member::VALID_ROLES - new_roles
      roles_to_set    = Member::VALID_ROLES & new_roles

      roles_to_remove.each { |role| member.delete_role(role) }
      roles_to_set.each    { |role| member.add_role(role) }

      member
    end

    def create_params
      params.expect(:member).permit(:org_id, :user_id)
    end

    def update_params
      params.expect(:member).permit(:member_id, :status, :roles)
    end
  end
end
