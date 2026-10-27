import { Controller } from "@hotwired/stimulus"

// Blur-to-save for a single entry log field.
//
//   ESC   -> throw the edit away and leave the field
//   blur  -> persist the edit, but only when it actually changed
//
// Once the text is deleted, leaving the field or pressing Enter asks instead: delete the
//   entry (a new one is just thrown away) or undo, which puts the last text back.
//
// Wired from app/views/orgs/entries/_editable_entry.html.erb and _new_entry.html.erb,
//   the dialog is app/views/orgs/entries/_emptied_dialog.html.erb.
//
export default class extends Controller {
  static targets = ["form", "log", "dialog"]

  connect() {
    this.original = this.logTarget.value
    this.lastText = this.original
    this.submitting = false
    this.statusPressed = false
  }

  get blank() {
    return this.logTarget.value.trim() === ""
  }

  // The text Undo puts back: as it was before the deleting began, not the last letter left.
  remember(event) {
    if (event.inputType?.startsWith("delete")) return
    if (!this.blank) this.lastText = this.logTarget.value
  }

  // ESC restores the value the field had when the controller connected. CTRL+Z is
  //   deliberately left alone: inside a text field that is the browser's own undo,
  //   and taking it over would be hostile.
  revert(event) {
    event.preventDefault()

    this.logTarget.value = this.original
    this.lastText = this.original
    this.statusPressed = false
    this.logTarget.blur()
  }

  // Any other way out of the field keeps the edit.
  saveIfChanged() {
    const pressedStatus = this.statusPressed
    this.statusPressed = false

    if (this.submitting) return
    if (this.blank) return this.askIfEmptied()
    if (pressedStatus) return
    if (this.logTarget.value === this.original) return

    // `submitting` is set by the submit event, not here: requestSubmit() runs the
    //   browser's own validation first, and a field the browser rejects never fires
    //   submit -- setting the flag up front would leave it stuck on forever.
    this.formTarget.requestSubmit()
  }

  // Also on Enter, which would otherwise get the browser's "fill out this field". A field
  //   that never had text (the new entry, untouched) has nothing to delete or undo.
  askIfEmptied(event) {
    if (!this.blank) return

    event?.preventDefault()
    if (this.lastText.trim() === "") return
    if (!this.dialogTarget.open) this.dialogTarget.showModal()
  }

  // The dialog's cancel (ESC) lands here too: closing it ourselves keeps the text coming back.
  undo(event) {
    event?.preventDefault()

    this.dialogTarget.close()
    this.logTarget.value = this.lastText
    this.logTarget.focus()
  }

  // a new entry was never saved, so throwing it away needs no request
  discard() {
    this.lastText = ""
    this.logTarget.value = ""
    this.dialogTarget.close()
  }

  // the delete went out, the Turbo Stream removes the entry
  closeDialog() {
    this.dialogTarget.close()
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

    if (event.detail && event.detail.success) {
      this.original = this.logTarget.value
      this.lastText = this.original
    }
  }
}
