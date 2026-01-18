"""
New Zealand Seek Job Scraping Script
Scrapes IT job data from Seek and saves to CSV file for data visualization
"""
import asyncio
import sys
import csv
import re
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional
from urllib.parse import quote_plus

try:
    from playwright.async_api import async_playwright, Browser, Page
except ImportError:
    print("Error: playwright is not installed. Please install it with: pip install playwright")
    print("Then run: playwright install")
    sys.exit(1)


def _normalize_city_name(city_name: str) -> str:
    """
    Normalize city name by removing common suffixes like CBD, Central, etc.
    
    Args:
        city_name: Raw city name from scraped data
    
    Returns:
        Normalized city name
    """
    if not city_name:
        return ""
    
    # Common suffixes to remove (case insensitive)
    suffixes_to_remove = [
        " cbd",
        " CBD",
        " central",
        " Central",
        " CENTRAL",
        " north",
        " North",
        " south",
        " South",
        " east",
        " East",
        " west",
        " West"
    ]
    
    normalized = city_name.strip()
    
    # Remove suffixes
    for suffix in suffixes_to_remove:
        if normalized.endswith(suffix):
            normalized = normalized[:-len(suffix)].strip()
    
    return normalized


async def scrape_seek_search(
    keywords: str,
    max_results: int = 10,
    headless: bool = False,
    browser_name: str = "firefox",
    country: str = "nz"
) -> List[Dict[str, Any]]:
    """
    Scrape job listings from Seek website
    
    Args:
        keywords: Search keywords
        max_results: Maximum number of results to return
        headless: Run browser in headless mode
        browser_name: Browser to use (chromium, firefox, webkit)
        country: Country code (nz for New Zealand)
    
    Returns:
        List of job dictionaries with job information
    """
    jobs = []
    
    try:
        async with async_playwright() as p:
            # Launch browser
            if browser_name == "chromium":
                browser = await p.chromium.launch(headless=headless)
            elif browser_name == "webkit":
                browser = await p.webkit.launch(headless=headless)
            else:
                browser = await p.firefox.launch(headless=headless)
            
            page = await browser.new_page()
            
            # Build Seek URL for New Zealand
            base_url = "https://www.seek.co.nz" if country.lower() == "nz" else "https://www.seek.com.au"
            search_query = quote_plus(keywords)
            url = f"{base_url}/jobs?keywords={search_query}"
            
            print(f"  Navigating to: {url}")
            await page.goto(url, wait_until="networkidle", timeout=30000)
            await page.wait_for_timeout(2000)  # Wait for page to load
            
            # Extract job listings
            job_cards = await page.query_selector_all('[data-automation="normalJob"]')
            
            if not job_cards:
                # Try alternative selectors
                job_cards = await page.query_selector_all('article[data-testid="job-card"]')
            
            if not job_cards:
                # Try another common selector
                job_cards = await page.query_selector_all('div[data-search-sol-meta]')
            
            print(f"  Found {len(job_cards)} job cards")
            
            # Extract data from each job card
            for i, card in enumerate(job_cards[:max_results]):
                try:
                    job_data = {}
                    
                    # Extract title
                    title_elem = await card.query_selector('a[data-automation="jobTitle"]')
                    if not title_elem:
                        title_elem = await card.query_selector('h3 a')
                    if not title_elem:
                        title_elem = await card.query_selector('[data-testid="job-title"]')
                    
                    if title_elem:
                        job_data['title'] = (await title_elem.inner_text()).strip()
                        # Extract URL
                        href = await title_elem.get_attribute('href')
                        if href:
                            if href.startswith('/'):
                                job_data['url'] = f"{base_url}{href}"
                            else:
                                job_data['url'] = href
                    else:
                        job_data['title'] = ""
                        job_data['url'] = ""
                    
                    # Extract company name
                    company_elem = await card.query_selector('a[data-automation="jobCompany"]')
                    if not company_elem:
                        company_elem = await card.query_selector('[data-testid="company-name"]')
                    if not company_elem:
                        company_elem = await card.query_selector('span[data-automation="jobCompany"]')
                    
                    if company_elem:
                        job_data['company'] = (await company_elem.inner_text()).strip()
                    else:
                        job_data['company'] = ""
                    
                    # Extract location
                    location_elem = await card.query_selector('a[data-automation="jobLocation"]')
                    if not location_elem:
                        location_elem = await card.query_selector('[data-testid="job-location"]')
                    if not location_elem:
                        location_elem = await card.query_selector('span[data-automation="jobLocation"]')
                    
                    if location_elem:
                        location_text = (await location_elem.inner_text()).strip()
                        job_data['location'] = location_text
                        # Try to extract city/region from location
                        location_parts = location_text.split(',')
                        city_normalized = ""
                        if len(location_parts) > 0:
                            raw_city = location_parts[0].strip()
                            # Normalize city name: remove CBD, Central, etc.
                            city_normalized = _normalize_city_name(raw_city)
                            job_data['city'] = city_normalized
                        if len(location_parts) > 1:
                            job_data['region'] = location_parts[-1].strip()
                        else:
                            # If no comma, use normalized city as region
                            job_data['region'] = city_normalized if city_normalized else location_text
                    else:
                        job_data['location'] = ""
                        job_data['city'] = ""
                        job_data['region'] = ""
                    
                    # Extract salary
                    salary_elem = await card.query_selector('span[data-automation="jobSalary"]')
                    if not salary_elem:
                        salary_elem = await card.query_selector('[data-testid="job-salary"]')
                    
                    if salary_elem:
                        salary_text = (await salary_elem.inner_text()).strip()
                        job_data['salary'] = salary_text
                        # Try to extract salary range
                        salary_match = re.search(r'(\d+(?:,\d{3})*)\s*-\s*(\d+(?:,\d{3})*)', salary_text)
                        if salary_match:
                            job_data['salary_min'] = salary_match.group(1).replace(',', '')
                            job_data['salary_max'] = salary_match.group(2).replace(',', '')
                        else:
                            single_match = re.search(r'(\d+(?:,\d{3})*)', salary_text)
                            if single_match:
                                job_data['salary_min'] = single_match.group(1).replace(',', '')
                                job_data['salary_max'] = ""
                    else:
                        job_data['salary'] = ""
                        job_data['salary_min'] = ""
                        job_data['salary_max'] = ""
                    
                    # Extract job description snippet
                    desc_elem = await card.query_selector('span[data-automation="jobShortDescription"]')
                    if not desc_elem:
                        desc_elem = await card.query_selector('[data-testid="job-abstract"]')
                    
                    if desc_elem:
                        job_data['description'] = (await desc_elem.inner_text()).strip()
                    else:
                        job_data['description'] = ""
                    
                    # Extract posted date
                    date_elem = await card.query_selector('span[data-automation="jobListingDate"]')
                    if not date_elem:
                        date_elem = await card.query_selector('[data-testid="job-date"]')
                    
                    if date_elem:
                        job_data['posted_date'] = (await date_elem.inner_text()).strip()
                    else:
                        job_data['posted_date'] = ""
                    
                    # Extract job ID from URL if possible
                    if job_data.get('url'):
                        job_id_match = re.search(r'/(\d+)$', job_data['url'])
                        if job_id_match:
                            job_data['job_id'] = job_id_match.group(1)
                        else:
                            job_id_match = re.search(r'/job/(\d+)', job_data['url'])
                            if job_id_match:
                                job_data['job_id'] = job_id_match.group(1)
                            else:
                                job_data['job_id'] = ""
                    else:
                        job_data['job_id'] = ""
                    
                    # Extract work type
                    work_type_elem = await card.query_selector('[data-automation="jobWorkType"]')
                    if work_type_elem:
                        job_data['work_type'] = (await work_type_elem.inner_text()).strip()
                    else:
                        job_data['work_type'] = ""
                    
                    job_data['job_type'] = ""
                    
                    if job_data.get('title'):  # Only add if we have at least a title
                        jobs.append(job_data)
                    
                except Exception as e:
                    print(f"    Warning: Failed to extract job {i+1}: {e}")
                    continue
            
            await browser.close()
            
    except Exception as e:
        print(f"  Error scraping jobs: {e}")
        import traceback
        traceback.print_exc()
    
    return jobs


NZ_IT_KEYWORDS = [
    "software engineer",
    "software developer",
    "full stack developer",
    "backend developer",
    "frontend developer",
    "devops engineer",
    "data engineer",
    "data scientist",
    "test engineer",
    "qa engineer",
    "product manager",
    "scrum master",
    "cloud engineer",
    "security engineer",
    "mobile developer",
    "python developer",
    "javascript developer",
    "java developer",
    "react developer",
    "node.js developer"
]

async def scrape_nz_jobs(max_per_keyword: int = 10, headless: bool = False, browser: str = "firefox", output_csv: str = None):
    """
    Scrape IT jobs from New Zealand Seek and save to CSV file
    
    Args:
        max_per_keyword: Maximum number of jobs to scrape per keyword (default: 10)
        headless: Whether to use headless mode
        browser: Browser to use (chromium, firefox, webkit)
        output_csv: Output CSV file path (default: nz_jobs_YYYYMMDD_HHMMSS.csv)
    """
    print("="*60)
    print("Starting to scrape IT job data from New Zealand Seek")
    print(f"Number of keywords: {len(NZ_IT_KEYWORDS)}")
    print(f"Max jobs per keyword: {max_per_keyword}")
    print(f"Estimated total jobs: {len(NZ_IT_KEYWORDS) * max_per_keyword}")
    print("="*60)
    
    # Generate timestamped filename if output file not specified
    if output_csv is None:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_csv = f"nz_jobs_{timestamp}.csv"
    
    output_path = Path(__file__).parent / output_csv
    
    # Store all job data
    all_jobs: List[Dict[str, Any]] = []
    total_success = 0
    
    for i, keyword in enumerate(NZ_IT_KEYWORDS, 1):
        print(f"\n{'='*60}")
        print(f"Processing keyword {i}/{len(NZ_IT_KEYWORDS)}: {keyword}")
        print(f"{'='*60}")
        
        try:
            # Call scraping function and get returned data
            jobs_data = await scrape_seek_search(
                keywords=keyword,
                max_results=max_per_keyword,
                headless=headless,
                browser_name=browser,
                country='nz'  # New Zealand
            )
            
            # Process returned data
            if jobs_data:
                # If returned data is a list
                if isinstance(jobs_data, list):
                    for job in jobs_data:
                        # Ensure each job has search_keyword field
                        if isinstance(job, dict):
                            job['search_keyword'] = keyword
                            all_jobs.append(job)
                        else:
                            # If not a dict, try to convert
                            all_jobs.append({
                                'search_keyword': keyword,
                                'title': str(job) if job else '',
                                'raw_data': str(job)
                            })
                # If returned data is a dict (single job)
                elif isinstance(jobs_data, dict):
                    jobs_data['search_keyword'] = keyword
                    all_jobs.append(jobs_data)
                
                keyword_count = len(jobs_data) if isinstance(jobs_data, list) else 1
                print(f"✓ Completed keyword: {keyword} (got {keyword_count} jobs)")
                total_success += keyword_count
            else:
                print(f"⚠ Keyword: {keyword} returned no data")
                
        except Exception as e:
            print(f"✗ Failed to process keyword: {keyword} - {e}")
            import traceback
            traceback.print_exc()
        
        # Wait between keywords to avoid too many requests
        if i < len(NZ_IT_KEYWORDS):
            print(f"\nWaiting 5 seconds before next keyword...")
            await asyncio.sleep(5)
    
    # Save data to CSV
    if all_jobs:
        _save_jobs_to_csv(all_jobs, output_path)
        print(f"\n{'='*60}")
        print(f"Data saved successfully!")
        print(f"File path: {output_path}")
        print(f"Total jobs scraped: {len(all_jobs)}")
        print(f"Successfully processed: {total_success} jobs")
        print(f"{'='*60}")
    else:
        print(f"\n{'='*60}")
        print("⚠ Warning: No job data was scraped")
        print(f"{'='*60}")


def _save_jobs_to_csv(jobs: List[Dict[str, Any]], output_path: Path):
    """
    Save job data to CSV file
    
    Args:
        jobs: List of job data dictionaries
        output_path: Output file path
    """
    if not jobs:
        print("Warning: No data to save")
        return
    
    # Collect all possible field names
    fieldnames = set()
    for job in jobs:
        if isinstance(job, dict):
            fieldnames.update(job.keys())
    
    # Define standard field order (geographic fields prioritized)
    standard_fields = [
        'search_keyword',  # Search keyword
        'title',           # Job title
        'company',         # Company name
        'location',        # Location
        'city',            # City
        'region',          # Region
        'area',            # Area
        'salary',          # Salary
        'salary_min',      # Minimum salary
        'salary_max',      # Maximum salary
        'description',     # Job description
        'url',             # Job URL
        'job_id',          # Job ID
        'posted_date',     # Posted date
        'work_type',       # Work type
        'job_type',        # Job type
    ]
    
    # Merge standard fields with other fields
    ordered_fields = []
    for field in standard_fields:
        if field in fieldnames:
            ordered_fields.append(field)
            fieldnames.remove(field)
    
    # Add other unlisted fields
    ordered_fields.extend(sorted(fieldnames))
    
    # Write to CSV file
    with open(output_path, 'w', newline='', encoding='utf-8-sig') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=ordered_fields, extrasaction='ignore')
        writer.writeheader()
        
        for job in jobs:
            if isinstance(job, dict):
                # Clean data: convert None to empty string
                cleaned_job = {}
                for key, value in job.items():
                    if value is None:
                        cleaned_job[key] = ''
                    elif isinstance(value, (list, dict)):
                        cleaned_job[key] = str(value)
                    else:
                        cleaned_job[key] = value
                writer.writerow(cleaned_job)


def main():
    """Main function"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Scrape IT job data from New Zealand Seek')
    parser.add_argument('--max-per-keyword', type=int, default=10, help='Maximum number of jobs to scrape per keyword (default: 10)')
    parser.add_argument('--headless', action='store_true', help='Use headless mode (no browser display)')
    parser.add_argument('--browser', type=str, choices=['chromium', 'firefox', 'webkit'], default='firefox', help='Browser engine to use (default: firefox)')
    parser.add_argument('--output', type=str, default=None, help='Output CSV filename (default: nz_jobs_YYYYMMDD_HHMMSS.csv)')
    
    args = parser.parse_args()
    
    print("Note: This script will scrape real job data from New Zealand Seek")
    print("Make sure playwright browsers are installed: playwright install")
    print()
    
    asyncio.run(scrape_nz_jobs(
        max_per_keyword=args.max_per_keyword,
        headless=args.headless,
        browser=args.browser,
        output_csv=args.output
    ))


if __name__ == "__main__":
    main()
