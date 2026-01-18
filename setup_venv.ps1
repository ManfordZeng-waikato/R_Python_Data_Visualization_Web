# PowerShell script to set up virtual environment for Windows
Write-Host "Setting up virtual environment..." -ForegroundColor Green

# Create virtual environment
python -m venv venv

# Activate virtual environment
Write-Host "Activating virtual environment..." -ForegroundColor Green
& .\venv\Scripts\Activate.ps1

# Upgrade pip
Write-Host "Upgrading pip..." -ForegroundColor Green
python -m pip install --upgrade pip

# Install requirements
Write-Host "Installing requirements..." -ForegroundColor Green
pip install -r requirements.txt

# Install Playwright browsers
Write-Host "Installing Playwright browsers (this may take a while)..." -ForegroundColor Green
python -m playwright install

Write-Host "`nSetup complete! Virtual environment is ready." -ForegroundColor Green
Write-Host "To activate the virtual environment in the future, run:" -ForegroundColor Yellow
Write-Host "  .\venv\Scripts\Activate.ps1" -ForegroundColor Cyan
Write-Host "`nTo run the scraper:" -ForegroundColor Yellow
Write-Host "  python scrape_nz_jobs.py --output nz_jobs_data.csv" -ForegroundColor Cyan
