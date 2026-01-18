#!/bin/bash
# Bash script to set up virtual environment for Linux/Mac

echo "Setting up virtual environment..."

# Create virtual environment
python3 -m venv venv

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
python -m pip install --upgrade pip

# Install requirements
echo "Installing requirements..."
pip install -r requirements.txt

# Install Playwright browsers
echo "Installing Playwright browsers (this may take a while)..."
python -m playwright install

echo ""
echo "Setup complete! Virtual environment is ready."
echo "To activate the virtual environment in the future, run:"
echo "  source venv/bin/activate"
echo ""
echo "To run the scraper:"
echo "  python scrape_nz_jobs.py --output nz_jobs_data.csv"
