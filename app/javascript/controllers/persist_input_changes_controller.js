// add this controller to input fields of forms
// when the user does not click ENTER, but leaves the input field
// and clicks somewhere else, their changes will be submitted
//
import { Controller } from "@hotwired/stimulus"
import { useClickOutside } from "stimulus-use"

export default class extends Controller {
  static targets = ["form"]

  connect() {
    useClickOutside(this)
  }

  clickOutside(event) {
    event.preventDefault()
    event.stopPropagation()
    this.formTarget.requestSubmit()
  }
}
