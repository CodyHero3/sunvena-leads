import requests
from bs4 import BeautifulSoup
from abc import ABC, abstractmethod
import logging
from datetime import datetime
import phonenumbers

logger = logging.getLogger(__name__)

class BaseScraper(ABC):
    """Base class for all lead scrapers"""
    
    def __init__(self, target_areas, target_counties=None):
        self.target_areas = target_areas
        self.target_counties = target_counties or []
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
        self.leads = []
    
    @abstractmethod
    def scrape(self):
        """Scrape leads from source"""
        pass
    
    def fetch_url(self, url, timeout=10):
        """Fetch and parse URL"""
        try:
            response = requests.get(url, headers=self.headers, timeout=timeout)
            response.raise_for_status()
            return BeautifulSoup(response.content, 'html.parser')
        except Exception as e:
            logger.error(f"Error fetching {url}: {e}")
            return None
    
    def normalize_phone(self, phone):
        """Normalize phone number to E.164 format"""
        if not phone:
            return None
        try:
            # Assume US by default
            parsed = phonenumbers.parse(phone, "US")
            if phonenumbers.is_valid_number(parsed):
                return phonenumbers.format_number(parsed, phonenumbers.PhoneNumberFormat.E164)
        except:
            pass
        return None
    
    def extract_emails(self, text):
        """Extract emails from text"""
        import re
        email_pattern = r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'
        return re.findall(email_pattern, text)
    
    def extract_phones(self, text):
        """Extract phone numbers from text"""
        import re
        phone_pattern = r'(?:\+1[-.\s]?)?\(?([0-9]{3})\)?[-.\s]?([0-9]{3})[-.\s]?([0-9]{4})'
        matches = re.findall(phone_pattern, text)
        phones = []
        for match in matches:
            phone = ''.join(match)
            normalized = self.normalize_phone(phone)
            if normalized:
                phones.append(normalized)
        return list(set(phones))
    
    def save_leads(self, session, source_name):
        """Save scraped leads to database"""
        from database.models import Lead, Contact, Property, SourceData
        
        saved_count = 0
        for lead_data in self.leads:
            try:
                # Check for duplicates
                existing = session.query(Lead).filter(
                    Lead.source_id == lead_data.get('source_id')
                ).first()
                
                if existing:
                    logger.info(f"Duplicate lead found: {lead_data.get('source_id')}")
                    continue
                
                # Create lead
                lead = Lead(
                    source=source_name,
                    source_url=lead_data.get('url'),
                    source_id=lead_data.get('source_id'),
                    primary_intent=lead_data.get('intent', 'unknown'),
                    status='new'
                )
                session.add(lead)
                session.flush()
                
                # Add contact info
                if lead_data.get('phone') or lead_data.get('email'):
                    contact = Contact(
                        lead_id=lead.id,
                        first_name=lead_data.get('first_name'),
                        last_name=lead_data.get('last_name'),
                        phone_number=lead_data.get('phone'),
                        email=lead_data.get('email'),
                        address=lead_data.get('address'),
                        city=lead_data.get('city'),
                        state=lead_data.get('state', 'FL'),
                        zip_code=lead_data.get('zip')
                    )
                    session.add(contact)
                
                # Add property info
                if lead_data.get('address'):
                    property_data = Property(
                        lead_id=lead.id,
                        address=lead_data.get('address'),
                        city=lead_data.get('city'),
                        state=lead_data.get('state', 'FL'),
                        zip_code=lead_data.get('zip'),
                        property_type=lead_data.get('property_type', 'single_family'),
                        year_built=lead_data.get('year_built'),
                        roof_age=lead_data.get('roof_age'),
                        ac_age=lead_data.get('ac_age'),
                        solar_potential=lead_data.get('solar_potential', 50)
                    )
                    session.add(property_data)
                
                # Store raw source data
                source_data = SourceData(
                    lead_id=lead.id,
                    source=source_name,
                    source_url=lead_data.get('url'),
                    raw_data=lead_data
                )
                session.add(source_data)
                
                session.commit()
                saved_count += 1
                
            except Exception as e:
                logger.error(f"Error saving lead: {e}")
                session.rollback()
        
        return saved_count
