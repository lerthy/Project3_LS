// API Configuration
// This file will be updated during deployment with the actual API Gateway URL

window.API_CONFIG = {
  // This will be replaced during the CI/CD pipeline
  API_GATEWAY_URL: 'https://r8iw9i2xuk.execute-api.us-east-1.amazonaws.com/dev/contact',
  
  // Fallback for local development
  FALLBACK_URL: 'https://sfexvebp8h.execute-api.eu-north-1.amazonaws.com/dev/contact'
};
