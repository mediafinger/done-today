require "rails_helper"

# The day page saves through Turbo Streams and the entry-form controller
#   (app/javascript/controllers/entry_form_controller.js), so these run in a browser.
#
RSpec.describe "Editing a day" do
  include ActionView::RecordIdentifier

  let(:org) { create(:org) }
  let(:project) { create(:project, org:) }
  let(:member) { create(:member, org:) }

  before do
    create(:participant, project:, member:)
    sign_in(member.user)
  end

  def create_entry(date: today, **)
    create(:entry, day: create(:day, project:, date:), member:, **)
  end

  def today = Time.zone.today

  def new_entry_field = find_field(placeholder: "What have you done today?")

  def log_field(entry) = find_field(dom_id(entry, :log))

  def entry_item(entry) = find("li##{dom_id(entry)}")

  # Types with real key events. Cuprite's fill_in ends with a synthetic blur, which saves the field.
  def retype(field, text)
    field.execute_script("this.value = ''")
    field.send_keys(text)
  end

  # survives Turbo Stream updates, not a page load or a Turbo Drive visit (both swap the body)
  def mark_page = execute_script("document.body.marked = true")

  def page_replaced? = !evaluate_script("document.body.marked")

  def focused_id = evaluate_script("document.activeElement.id")

  def wait_for_requests = page.driver.wait_for_network_idle

  def history_count(entry) = RecordHistory.for_org_record(org:, record: entry).count

  # deletes the text key by key, as a user would
  def erase(field)
    field.send_keys(:end, *Array.new(field.value.length, :backspace))
  end

  def open_dialog = find("dialog[open]")

  describe "adding an entry" do
    it "puts it above the field with Enter and starts the field over, without reloading" do
      visit edit_day_path(org, project, today)
      mark_page

      retype(new_entry_field, "Wrote a browser spec")
      new_entry_field.send_keys(:enter)

      within("#editable-entries") { expect(page).to have_field(with: "Wrote a browser spec") }
      expect(page).to have_no_text("You have not logged anything on this day yet")
      expect(new_entry_field.value).to eq("")
      expect(focused_id).to eq(new_entry_field[:id])
      expect(page_replaced?).to be(false)
    end

    it "saves it when the field is left" do
      visit edit_day_path(org, project, today)

      retype(new_entry_field, "Logged on blur")
      new_entry_field.send_keys(:tab)

      within("#editable-entries") { expect(page).to have_field(with: "Logged on blur") }
      expect(member.entries.pluck(:log)).to eq([ "Logged on blur" ])
    end
  end

  describe "changing an entry" do
    let!(:entry) { create_entry(status: "done") }

    before do
      visit edit_day_path(org, project, today)
      mark_page
    end

    it "saves the log when the field is left, once" do
      retype(log_field(entry), "Rewrote it")
      log_field(entry).send_keys(:tab)
      wait_for_requests

      expect(entry.reload.log).to eq("Rewrote it")
      expect(history_count(entry)).to eq(1)
      expect(page_replaced?).to be(false)
    end

    it "keeps the status and the caret on Enter" do
      retype(log_field(entry), "Rewrote it")
      log_field(entry).send_keys(:enter)
      wait_for_requests

      expect(entry.reload).to have_attributes(log: "Rewrote it", status: "done")
      expect(focused_id).to eq(dom_id(entry, :log))
      expect(evaluate_script("document.activeElement.selectionStart")).to eq("Rewrote it".length)
    end

    it "throws the edit away on ESC" do
      retype(log_field(entry), "Never mind")
      log_field(entry).send_keys(:escape)
      wait_for_requests

      expect(log_field(entry).value).to eq("Wrote some code")
      expect(focused_id).not_to eq(dom_id(entry, :log))
      expect(history_count(entry)).to eq(0)
    end

    it "saves the typed log along with a status button in one write" do
      retype(log_field(entry), "Back to work")
      within(entry_item(entry)) { click_button "doing" }

      within(entry_item(entry)) { expect(page).to have_button("doing", class: "btn-doing") }
      expect(entry.reload).to have_attributes(log: "Back to work", status: "doing")
      expect(history_count(entry)).to eq(1)
      expect(page_replaced?).to be(false)
    end
  end

  describe "deleting the text of an entry" do
    let!(:entry) { create_entry }

    before do
      visit edit_day_path(org, project, today)
      mark_page
      erase(log_field(entry))
    end

    it "asks when the field is left, and deletes the entry" do
      log_field(entry).send_keys(:tab)

      within(open_dialog) { click_button "Delete" }

      expect(page).to have_no_css("li##{dom_id(entry)}")
      expect(page).to have_text("You have not logged anything on this day yet")
      expect(Entry.exists?(entry.id)).to be(false)
      expect(RecordHistory.for_org_record(org:, record: entry).pluck(:event)).to eq([ "deleted" ])
      expect(page_replaced?).to be(false)
    end

    it "puts the text back on Undo, without saving" do
      log_field(entry).send_keys(:tab)

      within(open_dialog) { click_button "Undo" }

      expect(page).to have_no_css("dialog[open]")
      expect(log_field(entry).value).to eq("Wrote some code")
      expect(focused_id).to eq(dom_id(entry, :log))
      expect(history_count(entry)).to eq(0)
    end

    it "asks on Enter too, and ESC undoes" do
      log_field(entry).send_keys(:enter)
      open_dialog.send_keys(:escape)

      expect(page).to have_no_css("dialog[open]")
      expect(log_field(entry).value).to eq("Wrote some code")
      expect(Entry.exists?(entry.id)).to be(true)
    end
  end

  describe "leaving a started entry empty" do
    before { visit edit_day_path(org, project, today) }

    it "asks, and Delete throws the draft away without a request" do
      retype(new_entry_field, "Half a thought")
      erase(new_entry_field)
      new_entry_field.send_keys(:tab)

      within(open_dialog) { click_button "Delete" }

      expect(page).to have_no_css("dialog[open]")
      expect(new_entry_field.value).to eq("")
      expect(member.entries).to be_empty
    end

    it "puts the draft back on Undo" do
      retype(new_entry_field, "Half a thought")
      erase(new_entry_field)
      new_entry_field.send_keys(:tab)

      within(open_dialog) { click_button "Undo" }

      expect(new_entry_field.value).to eq("Half a thought")
      expect(focused_id).to eq(new_entry_field[:id])
    end

    it "does not ask when nothing was typed" do
      new_entry_field.send_keys(:tab)

      expect(page).to have_no_css("dialog[open]")
    end
  end

  describe "the lock on a past day" do
    let!(:entry) { create_entry(date: yesterday) }

    def yesterday = today - 1

    it "shows the entries read-only until the day is unlocked" do
      visit edit_day_path(org, project, yesterday)

      expect(page).to have_text("Wrote some code")
      expect(page).to have_no_field(dom_id(entry, :log))
      expect(page).to have_no_field(placeholder: "What have you done today?")

      click_link "🔒 unlock to edit"

      expect(page).to have_link("🔓 lock again")
      expect(log_field(entry).value).to eq("Wrote some code")
    end

    it "saves changes while unlocked and locks the day again" do
      visit edit_day_path(org, project, yesterday, unlocked: "1")

      retype(log_field(entry), "Fixed it late")
      log_field(entry).send_keys(:tab)
      wait_for_requests

      expect(entry.reload.log).to eq("Fixed it late")

      click_link "🔓 lock again"

      expect(page).to have_link("🔒 unlock to edit")
      expect(page).to have_no_field(dom_id(entry, :log))
    end
  end
end
