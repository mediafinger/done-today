# A member asking to join a project: name it so. Renames only, the rows stay.
#
class RenameAccessRequestsToParticipationRequests < ActiveRecord::Migration[8.1]
  def change
    safety_assured do # not deployed yet, no running app reads the old names
      rename_enum :access_request_status, :participation_request_status
      rename_table :access_requests, :participation_requests
    end

    rename_index :participation_requests, "index_access_requests_on_project_id_and_member_id_pending",
      "index_participation_requests_on_project_and_member_pending"
  end
end
