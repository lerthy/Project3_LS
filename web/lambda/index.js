const { Client } = require("pg");

exports.handler = async (event) => {
  try {
    const body = JSON.parse(event.body);

    const client = new Client({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASS,
      database: process.env.DB_NAME,
      port: 5432,
      ssl: { rejectUnauthorized: false } // needed if using AWS RDS
    });

    await client.connect();

    const query = `
      INSERT INTO contacts
      (full_name, email, phone, company, job_title, country, city, message)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
      RETURNING id;
    `;

    const values = [
      body.fullName,
      body.email,
      body.phone,
      body.company,
      body.jobTitle,
      body.country,
      body.city,
      body.message
    ];

    const result = await client.query(query, values);
    await client.end();

    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        success: true,
        id: result.rows[0].id,
        message: "Contact saved successfully!"
      }),
    };

  } catch (err) {
    console.error("Lambda error:", err);
    return {
      statusCode: 500,
      body: JSON.stringify({ success: false, error: "Internal Server Error" }),
    };
  }
};
