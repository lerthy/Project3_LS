// Security note: Database credentials are retrieved from AWS Secrets Manager or SSM.
import { Client } from "pg";
import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";
import { SSMClient, GetParameterCommand } from "@aws-sdk/client-ssm";

// Initialize AWS clients
const region = process.env.AWS_REGION || 'eu-north-1'; // Default to eu-north-1 if not set
const secretsClient = new SecretsManagerClient({ region });
const ssmClient = new SSMClient({ region });

// Cache for database credentials to avoid repeated SSM calls
let dbCredentials = null;

// Function to get database credentials from Secrets Manager or SSM (fallback for tests)
async function getDbCredentials() {
  if (dbCredentials) {
    return dbCredentials;
  }

  try {
    const secretArn = process.env.DB_SECRET_ARN;
    
    if (secretArn) {
      // Production: Use Secrets Manager
      console.log(`Retrieving credentials from Secrets Manager: ${secretArn}`);
      const secretData = await secretsClient.send(new GetSecretValueCommand({ SecretId: secretArn }));
      const secret = JSON.parse(secretData.SecretString || '{}');
      console.log(`Secrets Manager returned host: ${secret.host}`);
      
      dbCredentials = {
        host: secret.host,
        user: secret.username,
        password: secret.password,
        database: secret.database
      };
    } else {
      // Fallback: Use SSM parameters (for tests and local development)
      const [hostParam, userParam, passwordParam, dbParam] = await Promise.all([
        ssmClient.send(new GetParameterCommand({ Name: '/rds/rds_address' })),
        ssmClient.send(new GetParameterCommand({ Name: '/rds/db_username' })),
        ssmClient.send(new GetParameterCommand({ Name: '/rds/db_password', WithDecryption: true })),
        ssmClient.send(new GetParameterCommand({ Name: '/rds/db_name' }))
      ]);

      dbCredentials = {
        host: hostParam.Parameter.Value,
        user: userParam.Parameter.Value,
        password: passwordParam.Parameter.Value,
        database: dbParam.Parameter.Value
      };
    }

    return dbCredentials;
  } catch (error) {
    console.error("Failed to retrieve database credentials:", error);
    throw new Error("Database configuration error");
  }
}

export const handler = async (event) => {
  console.log("Lambda invoked with:", JSON.stringify(event, null, 2));
  
  // CORS headers for all responses
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type,Accept,Origin,X-Requested-With,Authorization,X-Api-Key",
    "Access-Control-Allow-Methods": "POST, OPTIONS, GET",
    "Access-Control-Max-Age": "86400",
    "Content-Type": "application/json"
  };

  try {
    // Handle OPTIONS request (CORS preflight)
    if (event.httpMethod === 'OPTIONS') {
      console.log("Handling OPTIONS request");
      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({ message: "CORS preflight" })
      };
    }

    // Only allow POST requests for writes
    if (event.httpMethod !== 'POST') {
      return {
        statusCode: 405,
        headers: corsHeaders,
        body: JSON.stringify({ 
          success: false, 
          error: "Method not allowed. Use POST." 
        })
      };
    }

    // Parse and validate request body
    let body;
    try {
      body = JSON.parse(event.body || '{}');
    } catch {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ 
          success: false, 
          error: "Invalid JSON in request body" 
        })
      };
    }

    // Validate required fields
    const requiredFields = ['name', 'email', 'phone', 'company', 'jobTitle', 'country', 'city', 'message'];
    const missingFields = requiredFields.filter(field => !body[field] || body[field].trim() === '');
    
    if (missingFields.length > 0) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ 
          success: false, 
          error: `Missing required fields: ${missingFields.join(', ')}` 
        })
      };
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(body.email)) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ 
          success: false, 
          error: "Invalid email format" 
        })
      };
    }

    // Get database credentials from SSM
    console.log("Getting database credentials...");
    const credentials = await getDbCredentials();
    console.log("Database credentials retrieved successfully");

    // Connect to database with increased timeout
    console.log(`Attempting to connect to database at ${credentials.host}`);
    const client = new Client({
      host: credentials.host,
      user: credentials.user,
      password: credentials.password,
      database: credentials.database,
      port: 5432,
      ssl: { rejectUnauthorized: false },
      connectionTimeoutMillis: 10000,  // Increased from 5000 to 10000
      query_timeout: 10000,           // Increased from 5000 to 10000
      statement_timeout: 10000        // Added statement timeout
    });

    // Add timeout wrapper for connection
    const connectWithTimeout = async () => {
      return Promise.race([
        client.connect(),
        new Promise((_, reject) => 
          setTimeout(() => reject(new Error('Connection timeout after 15 seconds')), 15000)
        )
      ]);
    };

    await connectWithTimeout();
    console.log("Database connection established successfully");

    // Ensure table exists (create if not exists)
    console.log("Creating table if not exists...");
    await client.query(`
      CREATE TABLE IF NOT EXISTS contacts (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255) NOT NULL,
        phone VARCHAR(50) NOT NULL,
        company VARCHAR(255) NOT NULL,
        job_title VARCHAR(255) NOT NULL,
        country VARCHAR(100) NOT NULL,
        city VARCHAR(100) NOT NULL,
        message TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log("Table ready");

    // Insert contact data
    console.log("Inserting contact data...");
    const query = `
      INSERT INTO contacts
      (name, email, phone, company, job_title, country, city, message)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
      RETURNING id, created_at;
    `;

    const values = [
      body.name.trim(),
      body.email.trim().toLowerCase(),
      body.phone.trim(),
      body.company.trim(),
      body.jobTitle.trim(),
      body.country.trim(),
      body.city.trim(),
      body.message.trim()
    ];

    const result = await client.query(query, values);
    console.log(`Contact inserted successfully with ID: ${result.rows[0].id}`);
    await client.end();
    console.log("Database connection closed");

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        success: true,
        id: result.rows[0].id,
        timestamp: result.rows[0].created_at,
        message: "Contact saved successfully!"
      }),
    };

  } catch (err) {
    console.error("Lambda error:", err);
    
    // Determine error type for better user feedback
    let errorMessage = "Internal Server Error";
    let statusCode = 500;
    
    if (err.code === 'ECONNREFUSED') {
      errorMessage = "Database connection failed";
      statusCode = 503;
    } else if (err.code === '23505') { // PostgreSQL unique violation
      errorMessage = "Duplicate entry detected";
      statusCode = 409;
    } else if (err.code === '23502') { // PostgreSQL not null violation
      errorMessage = "Required field missing";
      statusCode = 400;
    }
    
    return {
      statusCode: statusCode,
      headers: corsHeaders,
      body: JSON.stringify({ 
        success: false, 
        error: errorMessage,
        ...(process.env.NODE_ENV === 'development' && { details: err.message })
      }),
    };
  }
};
