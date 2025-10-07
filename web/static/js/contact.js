// Contact Form Handler
// Handles form submission to API Gateway -> Lambda -> RDS

class ContactForm {
  constructor() {
    this.form = document.querySelector('[data-purpose="contact-form"]');
    this.submitButton = this.form?.querySelector('button[type="submit"]');
    
    // Wait a moment for config to load, then get endpoint
    setTimeout(() => {
      this.apiEndpoint = this.getApiEndpoint();
    }, 100);
    
    if (this.form) {
      this.init();
    }
  }

  init() {
    this.form.addEventListener('submit', this.handleSubmit.bind(this));
  }

  getApiEndpoint() {
    // Debug logging
    console.log('API_CONFIG object:', window.API_CONFIG);
    console.log('API_CONFIG exists:', !!window.API_CONFIG);
    
    // Try to get URL from config, fallback to environment or placeholder
    if (window.API_CONFIG && window.API_CONFIG.API_GATEWAY_URL && 
        !window.API_CONFIG.API_GATEWAY_URL.includes('{{')) {
      console.log('Using dynamic API URL:', window.API_CONFIG.API_GATEWAY_URL);
      return window.API_CONFIG.API_GATEWAY_URL;
    }
    
    // Fallback for development/testing
    console.warn('Falling back to placeholder API URL - config not loaded properly!');
    return 'https://api.example.com/contact';
  }

  getApiKey() {
    // Try to get API key from config
    if (window.API_CONFIG && window.API_CONFIG.API_KEY && 
        !window.API_CONFIG.API_KEY.includes('{{')) {
      console.log('Using dynamic API key');
      return window.API_CONFIG.API_KEY;
    }
    
    // Fallback for development
    console.warn('Using fallback API key - config not loaded properly!');
    return window.API_CONFIG?.FALLBACK_API_KEY || 'development-api-key';
  }

  async handleSubmit(event) {
    event.preventDefault();
    
    if (!this.validateForm()) {
      return;
    }

    const formData = this.getFormData();
    
    try {
      this.setLoadingState(true);
      await this.submitForm(formData);
      this.showSuccess();
      this.resetForm();
    } catch (error) {
      console.error('Form submission error:', error);
      this.showError(error.message);
    } finally {
      this.setLoadingState(false);
    }
  }

  validateForm() {
    const requiredFields = this.form.querySelectorAll('[required]');
    let isValid = true;

    requiredFields.forEach(field => {
      if (!field.value.trim()) {
        this.showFieldError(field, 'This field is required');
        isValid = false;
      } else {
        this.clearFieldError(field);
      }
    });

    // Email validation
    const emailField = this.form.querySelector('[type="email"]');
    if (emailField && emailField.value) {
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailRegex.test(emailField.value)) {
        this.showFieldError(emailField, 'Please enter a valid email address');
        isValid = false;
      }
    }

    return isValid;
  }

  getFormData() {
    const formData = new FormData(this.form);
    
    return {
      name: formData.get('fullName'),
      email: formData.get('email'),
      phone: formData.get('phone'),
      company: formData.get('company'),
      jobTitle: formData.get('jobTitle'),
      country: formData.get('country'),
      city: formData.get('city'),
      message: formData.get('message')
    };
  }

  async submitForm(data) {
    // Get the API endpoint fresh each time
    const apiEndpoint = this.getApiEndpoint();
    console.log('About to submit to:', apiEndpoint);
    
    const response = await fetch(apiEndpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-API-Key': this.getApiKey()
      },
      body: JSON.stringify(data)
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.message || `HTTP ${response.status}: ${response.statusText}`);
    }

    const result = await response.json();
    
    if (!result.success) {
      throw new Error(result.error || 'Submission failed');
    }

    return result;
  }

  setLoadingState(isLoading) {
    if (this.submitButton) {
      this.submitButton.disabled = isLoading;
      this.submitButton.textContent = isLoading ? 'Submitting...' : 'Submit';
    }
  }

  showSuccess() {
    this.showMessage('Thank you! Your message has been sent successfully. We\'ll get back to you soon.', 'success');
  }

  showError(message) {
    this.showMessage(`Error: ${message}. Please try again or contact us directly.`, 'error');
  }

  showMessage(message, type) {
    // Remove existing messages
    const existingMessage = this.form.querySelector('.form-message');
    if (existingMessage) {
      existingMessage.remove();
    }

    // Create new message
    const messageDiv = document.createElement('div');
    messageDiv.className = `form-message alert ${type === 'success' ? 'alert-success' : 'alert-danger'}`;
    messageDiv.textContent = message;
    
    // Insert at the top of the form
    this.form.insertBefore(messageDiv, this.form.firstChild);
    
    // Scroll to message
    messageDiv.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }

  showFieldError(field, message) {
    field.classList.add('is-invalid');
    
    // Remove existing error
    const existingError = field.parentNode.querySelector('.invalid-feedback');
    if (existingError) {
      existingError.remove();
    }
    
    // Add new error
    const errorDiv = document.createElement('div');
    errorDiv.className = 'invalid-feedback';
    errorDiv.textContent = message;
    field.parentNode.appendChild(errorDiv);
  }

  clearFieldError(field) {
    field.classList.remove('is-invalid');
    const errorDiv = field.parentNode.querySelector('.invalid-feedback');
    if (errorDiv) {
      errorDiv.remove();
    }
  }

  resetForm() {
    this.form.reset();
    
    // Clear any validation states
    const invalidFields = this.form.querySelectorAll('.is-invalid');
    invalidFields.forEach(field => this.clearFieldError(field));
  }
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  new ContactForm();
});

// Export for testing
if (typeof module !== 'undefined' && module.exports) {
  module.exports = ContactForm;
}
