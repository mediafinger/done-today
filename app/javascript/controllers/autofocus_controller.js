import { Controller } from "@hotwired/stimulus"

// Puts the cursor at the end of a field as soon as it enters the DOM.
//
// Replaces the inline <script> that used to set document.location.hash after a
//   create: that fought Turbo and would break under a CSP nonce. The plain
//   autofocus attribute only fires on a full page load, not on the Turbo Stream
//   that now re-renders the new-entry form, so a controller has to do it.
//
export default class extends Controller {
  connect() {
    if (this.element === document.activeElement) return

    this.element.focus()

    const value = this.element.value
    if (typeof value === "string") this.element.setSelectionRange(value.length, value.length)
  }
}
