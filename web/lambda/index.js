// Security note: Secrets (DB creds, S3 bucket name, etc.) must be stored in AWS Secrets Manager or SSM Parameter Store, not hardcoded.
import { Client } from "pg";

export const handler = async (event) => {
  // CORS headers for all responses
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Content-Type": "application/json"
  };

  try {
    // Handle OPTIONS request (CORS preflight)
    if (event.httpMethod === 'OPTIONS') {
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

    // Connect to database
    const client = new Client({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASS,
      database: process.env.DB_NAME,
      port: 5432,
      ssl: { rejectUnauthorized: false },
      connectionTimeoutMillis: 5000,
      query_timeout: 5000
    });

    await client.connect();

    // Ensure table exists (create if not exists)
    await client.query(`
      CREATE TABLE IF NOT EXISTS contacts (
        id SERIAL PRIMARY KEY,
        full_name VARCHAR(255) NOT NULL,
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

    // Insert contact data
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
    await client.end();

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
