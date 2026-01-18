# Virtual Environment Setup Guide

This guide will help you set up a virtual environment for the New Zealand Seek job scraper to avoid conflicts with your system Python environment.

## Windows (PowerShell)

### Quick Setup

Run the setup script:
```powershell
.\setup_venv.ps1
```

If you get an execution policy error, run this first:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Manual Setup

1. **Create virtual environment:**
   ```powershell
   python -m venv venv
   ```

2. **Activate virtual environment:**
   ```powershell
   .\venv\Scripts\Activate.ps1
   ```

3. **Upgrade pip:**
   ```powershell
   python -m pip install --upgrade pip
   ```

4. **Install dependencies:**
   ```powershell
   pip install -r requirements.txt
   ```

5. **Install Playwright browsers:**
   ```powershell
   python -m playwright install
   ```

## Linux/Mac

### Quick Setup

Run the setup script:
```bash
chmod +x setup_venv.sh
./setup_venv.sh
```

### Manual Setup

1. **Create virtual environment:**
   ```bash
   python3 -m venv venv
   ```

2. **Activate virtual environment:**
   ```bash
   source venv/bin/activate
   ```

3. **Upgrade pip:**
   ```bash
   python -m pip install --upgrade pip
   ```

4. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

5. **Install Playwright browsers:**
   ```bash
   python -m playwright install
   ```

## Usage

After setting up the virtual environment:

1. **Activate the virtual environment** (if not already activated):
   - Windows: `.\venv\Scripts\Activate.ps1`
   - Linux/Mac: `source venv/bin/activate`

2. **Run the scraper:**
   ```bash
   python scrape_nz_jobs.py --output nz_jobs_data.csv
   ```

3. **Deactivate the virtual environment** when done:
   ```bash
   deactivate
   ```

## Dependencies

The project requires:
- Python 3.7 or higher
- playwright (for web scraping)
- Browser binaries (installed via `playwright install`)

All dependencies are listed in `requirements.txt`.
