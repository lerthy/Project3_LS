-- Setup script for contact form database
-- Connect to the contacts database and create the required table

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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_contacts_email ON contacts(email);
CREATE INDEX IF NOT EXISTS idx_contacts_created_at ON contacts(created_at);
CREATE INDEX IF NOT EXISTS idx_contacts_company ON contacts(company);

-- Insert a test record to verify everything works
INSERT INTO contacts (name, email, phone, company, job_title, country, city, message) 
VALUES ('Test User', 'test@example.com', '555-0123', 'Test Company', 'Developer', 'Test Country', 'Test City', 'This is a test message to verify the database setup.');

-- Display the table structure and sample data
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'contacts' 
ORDER BY ordinal_position;

SELECT * FROM contacts ORDER BY created_at DESC LIMIT 5;
\d contacts;

-- Show all records
SELECT * FROM contacts;
