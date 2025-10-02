// API Configuration
// This file will be updated during deployment with the actual API Gateway URL and API key

window.API_CONFIG = {
  // These will be replaced during the CI/CD pipeline
  API_GATEWAY_URL: '{{API_GATEWAY_URL}}',
  API_KEY: '{{API_KEY}}',
  
  // Fallback for local development
  FALLBACK_URL: 'https://sfexvebp8h.execute-api.eu-north-1.amazonaws.com/dev/contact',
  FALLBACK_API_KEY: 'development-api-key'
};
