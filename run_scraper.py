#!/usr/bin/env python
"""Main scraping orchestrator"""

import logging
import sys
import os
from datetime import datetime

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def run_scrapers():
    """Run all scrapers sequentially"""
    try:
        from database import get_session, Base, engine
        from database.models import ScrapeJob
        from scrapers.real_estate import ZillowScraper, RealtorScraper, CraiglistScraper, AuctionScraper
        from scrapers.search_news import GoogleSearchScraper, LocalNewsScraper, YelpScraper
        from scrapers.social_media import RedditScraper, TwitterScraper
        from scoring.scorer import LeadScorer
        from config import config
        
        # Ensure database exists
        Base.metadata.create_all(engine)
        
        session = get_session()
        total_new = 0
        
        logger.info("="*60)
        logger.info("STARTING LEAD SCRAPING PROCESS")
        logger.info("="*60)
        
        scrapers = [
            ('zillow', ZillowScraper(config.TARGET_AREAS)),
            ('realtor', RealtorScraper(config.TARGET_AREAS)),
            ('craigslist', CraiglistScraper(config.TARGET_AREAS)),
            ('auction', AuctionScraper(config.TARGET_AREAS)),
            ('google_search', GoogleSearchScraper(config.TARGET_AREAS)),
            ('local_news', LocalNewsScraper(config.TARGET_AREAS)),
            ('yelp', YelpScraper(config.TARGET_AREAS)),
            ('reddit', RedditScraper(config.TARGET_AREAS)),
            ('twitter', TwitterScraper(config.TARGET_AREAS)),
        ]
        
        for source_name, scraper in scrapers:
            try:
                logger.info(f"\nScraping {source_name.upper()}...")
                
                # Create job record
                job = ScrapeJob(
                    source=source_name,
                    status='running',
                    started_at=datetime.utcnow()
                )
                session.add(job)
                session.commit()
                
                # Run scraper
                leads = scraper.scrape()
                saved = scraper.save_leads(session, source_name)
                
                # Update job
                job.status = 'completed'
                job.leads_found = len(leads)
                job.leads_new = saved
                job.completed_at = datetime.utcnow()
                session.commit()
                
                logger.info(f"✓ {source_name}: {saved} new leads")
                total_new += saved
            
            except Exception as e:
                logger.error(f"✗ {source_name} error: {str(e)}")
                job.status = 'failed'
                job.error_message = str(e)
                session.commit()
        
        # Score all leads
        logger.info("\n" + "="*60)
        logger.info("SCORING LEADS")
        logger.info("="*60)
        
        scorer = LeadScorer()
        scored = scorer.score_all_leads()
        
        logger.info(f"\n" + "="*60)
        logger.info(f"COMPLETE: {total_new} new leads, {scored} scored")
        logger.info("="*60)
        
        return total_new
    
    except Exception as e:
        logger.error(f"FATAL ERROR: {str(e)}", exc_info=True)
        return 0

if __name__ == '__main__':
    total = run_scrapers()
    sys.exit(0 if total >= 0 else 1)
