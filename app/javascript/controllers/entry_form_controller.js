import { Controller } from "@hotwired/stimulus"

// Blur-to-save for a single entry log field.
//
//   ESC   -> throw the edit away and leave the field
//   blur  -> persist the edit, but only when it actually changed
//
// Wired from app/views/orgs/entries/_editable_entry.html.erb and _new_entry.html.erb.
//
export default class extends Controller {
  static targets = ["log"]

  connect() {
    this.original = this.logTarget.value
    this.submitting = false
    this.statusPressed = false
  }

  // ESC restores the value the field had when the controller connected. CTRL+Z is
  //   deliberately left alone: inside a text field that is the browser's own undo,
  //   and taking it over would be hostile.
  revert(event) {
    event.preventDefault()

    this.logTarget.value = this.original
    this.statusPressed = false
    this.logTarget.blur()
  }

  // Any other way out of the field keeps the edit.
  saveIfChanged() {
    const pressedStatus = this.statusPressed
    this.statusPressed = false

    if (this.submitting || pressedStatus) return
    if (this.logTarget.value === this.original) return

    // `submitting` is set by the submit event, not here: requestSubmit() runs the
    //   browser's own validation first, and a field the browser rejects never fires
    //   submit -- setting the flag up front would leave it stuck on forever.
    this.element.requestSubmit()
  }

  // The double-submit trap: a status button is a submit button, so pressing it
  //   blurs the field *before* the click lands. Without this note the blur would
  //   save, and the click would save again -- two writes for one user action.
  //   The button's own submit carries both the log and the status, so the blur
  //   stands down and lets the click do the work.
  noteStatusPress() {
    this.statusPressed = true
  }

  // Focus coming back to the field means the press never turned into a click
  //   (the pointer was dragged off the button), so the note has to go.
  clearStatusPress() {
    this.statusPressed = false
  }

  markSubmitting() {
    this.submitting = true
  }

  // Turbo fires this once the response is in. Resetting matters for the error path,
  //   where the form is not replaced and has to stay usable. The update response is
  //   morphed in, which keeps this controller instance alive, so the saved value
  //   becomes the new baseline for ESC and for the next blur.
  submitEnded(event) {
    this.submitting = false

    if (event.detail && event.detail.success) this.original = this.logTarget.value
  }
}
