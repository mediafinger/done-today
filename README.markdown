# Done today

...is supposed to become a simple app multi-tenant app to log daily activities.

## Data model

The data model should look like this:

### Org

* has_many :projects
* has_many :members, inverse_of: :org, dependent: :destroy
* has_many :users, through: :members
* --
* name (unique)

### User

* has_many :memberships, class_name: "Member", inverse_of: :user, dependent: :destroy
* has_many :orgs, through: :memberships
* --
* email (unique)
* password_digest
* name
* bio (text)
* profile_picture (attachment)
* admin (boolean)

### Member

* belongs_to :org, inverse_of: :members
* belongs_to :user, inverse_of: :memberships
* --
* has_many :participations, class_name: "Participant", inverse_of: :member, dependent: :destroy
* has_many :projects, through: :participations
* --
* roles (member | owner)
* send_reminder_at (datetime)

### Project

* belongs_to :org
* --
* has_many :days
* has_many :participants, inverse_of: :project, dependent: :destroy
* hash_many :entries, through: :days
* has_many :members, through: :participants
* --
* name (unique for org)

### Participant

* belongs_to :org
* belongs_to :project, inverse_of: :participants
* belongs_to :member, inverse_of: :participations
* --
* roles (participant | observer | owner)

### Day

* belongs_to :org
* belongs_to :project, inverse_of: :day
* --
* has_many :entries, inverse_of: :day, dependent: :destroy
* --
* date (date)

### Entry

* belongs_to :day
* belongs_to :org
* belongs_to :member
* --
* log (text)
* status (todo | doing | done)

### Integrations

* belongs_to :org
* --
* has_many :project_integrations
* --
* service (email | slack | ...)
* credentials (jsonb)
* type (reminder | notification | summary)
* template (erb text)

### ProjectIntegration

* belongs_to :org
* belongs_to :project
* belongs_to :integration

### RecordHistory

* belongs_to :org

Store kind of an event log of all (relevant) changes to the database.
