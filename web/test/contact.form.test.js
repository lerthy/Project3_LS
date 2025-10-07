import { describe, it, expect, beforeEach, vi } from 'vitest';

// Load config first to set window.API_CONFIG
import '../static/js/config.js';

// System under test
import ContactForm from '../static/js/contact.js';

function mountContactForm() {
  document.body.innerHTML = `
    <form data-purpose="contact-form">
      <input id="full-name" name="fullName" required type="text" value="John Doe" />
      <input id="email" name="email" required type="email" value="john@example.com" />
      <input id="phone" name="phone" required type="tel" value="123" />
      <input id="company" name="company" required type="text" value="Acme" />
      <input id="job-title" name="jobTitle" required type="text" value="Engineer" />
      <input id="country" name="country" required type="text" value="US" />
      <input id="city" name="city" required type="text" value="NYC" />
      <textarea id="message" name="message" required>Hi</textarea>
      <button type="submit">Submit</button>
    </form>
  `;
  // instantiate
  // eslint-disable-next-line no-new
  new ContactForm();
}

describe('ContactForm', () => {
  beforeEach(() => {
    // Reset fetch for each test
    global.fetch = vi.fn();
  });

  it('fires fetch POST to API Gateway URL on valid submit', async () => {
    mountContactForm();

    // Arrange
    global.fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ success: true })
    });

    const form = document.querySelector('[data-purpose="contact-form"]');

    // Act
    const submitEvent = new Event('submit');
    await form.dispatchEvent(submitEvent);

    // Assert
    expect(global.fetch).toHaveBeenCalledTimes(1);
    const [url, options] = global.fetch.mock.calls[0];
    expect(typeof url).toBe('string');
    expect(options.method).toBe('POST');
    expect(options.headers['Content-Type']).toBe('application/json');
  });

  it('shows validation error and does not call fetch when required missing', async () => {
    document.body.innerHTML = `
      <form data-purpose="contact-form">
        <input id="full-name" name="fullName" required type="text" value="" />
        <input id="email" name="email" required type="email" value="not-an-email" />
        <textarea id="message" name="message" required></textarea>
        <button type="submit">Submit</button>
      </form>
    `;
    // eslint-disable-next-line no-new
    new ContactForm();

    const form = document.querySelector('[data-purpose="contact-form"]');
    const submitEvent = new Event('submit');
    await form.dispatchEvent(submitEvent);

    expect(global.fetch).not.toHaveBeenCalled();
    // invalid state applied
    expect(document.querySelector('.is-invalid')).not.toBeNull();
  });
});


