import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form"]

  connect() {}

  change(event) {
    event.preventDefault()
    event.stopPropagation()
    this.formTarget.requestSubmit()
  }
}
