# Testing and Deployment Guide

Comprehensive guide for testing the two-app system and preparing for App Store deployment.

## Table of Contents

1. [Local Testing](#local-testing)
2. [CloudKit Setup](#cloudkit-setup)
3. [App Store Connect Configuration](#app-store-connect-configuration)
4. [Testing Data Sharing](#testing-data-sharing)
5. [TestFlight Beta Testing](#testflight-beta-testing)
6. [Production Deployment](#production-deployment)

---

## Local Testing

### Test 1: Patient App Basic Functionality

**Objective**: Verify patient app works independently

1. **Launch Patient App**
   ```bash
   # Select OralableApp scheme
   # Run on simulator: ⌘R
   ```

2. **Test Onboarding**
   - [ ] Onboarding screens display correctly
   - [ ] "Sign In with Apple" button appears
   - [ ] Can navigate through onboarding pages

3. **Test Authentication** (in simulator, uses fake Apple ID)
   - [ ] Tap "Sign In with Apple"
   - [ ] Authentication completes
   - [ ] App navigates to main tabs

4. **Test Main Tabs**
   - [ ] Dashboard loads
   - [ ] Devices view displays
   - [ ] History view accessible
   - [ ] Share view loads
   - [ ] Settings accessible

5. **Test Share Code Generation**
   - [ ] Navigate to Share tab
   - [ ] Tap "Generate Share Code"
   - [ ] 6-digit code displays
   - [ ] Code can be copied
   - [ ] Expiry timer shows (48 hours)

### Test 2: Dentist App Basic Functionality

**Objective**: Verify dentist app works independently

1. **Launch Dentist App**
   ```bash
   # Select OralableForDentists scheme
   # Run on simulator: ⌘R
   ```

2. **Test Onboarding**
   - [ ] Dentist onboarding screens display
   - [ ] Professional branding/messaging
   - [ ] "Sign In with Apple" button appears

3. **Test Authentication**
   - [ ] Sign in with Apple works
   - [ ] App navigates to patient list

4. **Test Empty State**
   - [ ] "No Patients Yet" message displays
   - [ ] "Add Patient" button visible
   - [ ] Instructions are clear

5. **Test Settings**
   - [ ] Settings tab accessible
   - [ ] Account info displays
   - [ ] Current plan shows (Starter - Free)
   - [ ] Upgrade prompt accessible

### Test 3: Subscription UI

**Patient App (Basic vs Premium)**:

1. **Test Subscription View**
   - [ ] Navigate to Settings → Subscription
   - [ ] Basic tier features listed
   - [ ] Premium tier features listed
   - [ ] Pricing displays correctly
   - [ ] "Upgrade" button works

2. **Test Subscription Limits**
   - [ ] Share view shows "Share with 1 dentist" on Basic
   - [ ] Attempt to share with 2nd dentist shows upgrade prompt

**Dentist App (Starter/Professional/Practice)**:

1. **Test Upgrade View**
   - [ ] Settings → Upgrade
   - [ ] All 3 tiers display
   - [ ] Features comparison table
   - [ ] Monthly pricing shows
   - [ ] Can select different tiers

2. **Test Patient Limits**
   - [ ] Starter: Shows 5 patient limit
   - [ ] Add 5th patient succeeds
   - [ ] 6th patient shows upgrade prompt

---

## CloudKit Setup

### Prerequisites

- Active Apple Developer account ($99/year)
- Access to Apple Developer Portal
- CloudKit access enabled

### Step 1: Create CloudKit Container

1. Go to: https://developer.apple.com/account
2. Navigate to **Certificates, Identifiers & Profiles**
3. Click **Identifiers** → **+** button
4. Select **App IDs** → **Continue**
5. Create two App IDs:
   - **Oralable Patient App**
     - Bundle ID: `com.jacdental.oralable`
     - Capabilities: CloudKit, Sign in with Apple, In-App Purchase
   - **Oralable for Dentists**
     - Bundle ID: `com.jacdental.oralable.dentist`
     - Capabilities: CloudKit, Sign in with Apple, In-App Purchase

### Step 2: Configure CloudKit Container

1. Go to **CloudKit Dashboard**: https://icloud.developer.apple.com/dashboard
2. Select your container: `iCloud.com.jacdental.oralable.shared`
3. Click **Schema** → **Record Types**

### Step 3: Create Record Types

#### Record Type 1: ShareInvitation

Fields:
- `shareCode` (String, Indexed, Queryable)
- `patientID` (String, Indexed, Queryable)
- `dentistID` (String, Queryable) - initially empty
- `createdDate` (Date/Time)
- `expiryDate` (Date/Time, Queryable)
- `isActive` (Int64, Queryable) - 1 for active, 0 for inactive

Indexes:
- `shareCode` - Queryable, Sortable
- `patientID` - Queryable
- `expiryDate` - Queryable
- `isActive` - Queryable

#### Record Type 2: SharedPatientData

Fields:
- `patientID` (String, Indexed, Queryable)
- `dentistID` (String, Indexed, Queryable)
- `shareCode` (String)
- `accessGrantedDate` (Date/Time)
- `isActive` (Int64, Queryable)
- `patientName` (String, Optional) - patient can choose to share
- `dentistName` (String, Optional)
- `lastDataUpdate` (Date/Time, Optional)

Indexes:
- `patientID` + `isActive` - Compound index for patient queries
- `dentistID` + `isActive` - Compound index for dentist queries

#### Record Type 3: HealthDataRecord

Fields:
- `patientID` (String, Indexed, Queryable)
- `recordingDate` (Date/Time, Indexed, Queryable)
- `sessionDuration` (Double)
- `bruxismEvents` (Int64)
- `averageIntensity` (Double)
- `peakIntensity` (Double)
- `measurements` (Bytes) - Serialized sensor data
- `dataType` (String) - "bruxism", "heartRate", "oxygenSaturation"

Indexes:
- `patientID` + `recordingDate` - Compound index for date range queries

### Step 4: Set Permissions

For each record type:
1. Click on record type
2. Go to **Security Roles**
3. Set permissions:

**ShareInvitation**:
- Public: Read, Write (so dentists can claim codes)
- Authenticated: Read, Write

**SharedPatientData**:
- Public: Read, Write (cross-app sharing)
- Authenticated: Read, Write

**HealthDataRecord**:
- Public: Read (dentists read patient data)
- Authenticated: Write (patients write data)

### Step 5: Deploy Schema

1. Review all record types
2. Click **Deploy to Production**
3. Confirm deployment

**⚠️ Warning**: Once deployed to production, schema changes require migration

---

## App Store Connect Configuration

### Step 1: Create App Store Listings

1. Go to: https://appstoreconnect.apple.com
2. Click **My Apps** → **+** button

#### Create Patient App

- **App Name**: Oralable
- **Primary Language**: English (US)
- **Bundle ID**: com.jacdental.oralable
- **SKU**: ORALABLE-PATIENT-001
- **Category**: Health & Fitness / Medical

#### Create Dentist App

- **App Name**: Oralable for Dentists
- **Primary Language**: English (US)
- **Bundle ID**: com.jacdental.oralable.dentist
- **SKU**: ORALABLE-DENTIST-001
- **Category**: Medical / Productivity

### Step 2: Configure In-App Purchases

#### Patient App Subscriptions

1. Navigate to **Oralable** → **Features** → **In-App Purchases**
2. Click **+** → **Auto-Renewable Subscription**
3. Create **Subscription Group**: "Oralable Premium"

**Premium Monthly**:
- Product ID: `com.jacdental.oralable.premium.monthly`
- Price: €9.99/month
- Subscription Duration: 1 Month
- Description: "Premium access to advanced features"

**Premium Yearly**:
- Product ID: `com.jacdental.oralable.premium.yearly`
- Price: €99.99/year
- Subscription Duration: 1 Year
- Description: "Premium access with 2 months free"

#### Dentist App Subscriptions

1. Navigate to **Oralable for Dentists** → **In-App Purchases**
2. Create **Subscription Group**: "Dentist Plans"

**Professional Monthly**:
- Product ID: `com.jacdental.oralable.dentist.professional.monthly`
- Price: €29.99/month
- Duration: 1 Month

**Professional Yearly**:
- Product ID: `com.jacdental.oralable.dentist.professional.yearly`
- Price: €299.99/year
- Duration: 1 Year

**Practice Monthly**:
- Product ID: `com.jacdental.oralable.dentist.practice.monthly`
- Price: €99.99/month
- Duration: 1 Month

**Practice Yearly**:
- Product ID: `com.jacdental.oralable.dentist.practice.yearly`
- Price: €999.99/year
- Duration: 1 Year

### Step 3: Set Up Sandbox Testing

1. **Settings** → **Users and Access** → **Sandbox Testers**
2. Create test accounts:
   - `patient.test@example.com` - for patient app
   - `dentist.test@example.com` - for dentist app
3. Set region to match your pricing (EUR)

---

## Testing Data Sharing

### End-to-End Share Flow Test

**Prerequisites**:
- Both apps installed on same or different devices/simulators
- CloudKit schema deployed
- Both apps use same iCloud container

**Test Scenario**:

1. **Patient Generates Code**
   - [ ] Launch patient app
   - [ ] Sign in
   - [ ] Navigate to Share tab
   - [ ] Tap "Generate Share Code"
   - [ ] Note the 6-digit code (e.g., 123456)
   - [ ] Verify code appears in CloudKit Dashboard
     - Go to Data → Public → ShareInvitation
     - Find record with shareCode = 123456
     - Verify isActive = 1, dentistID = ""

2. **Dentist Enters Code**
   - [ ] Launch dentist app
   - [ ] Sign in with different Apple ID
   - [ ] Tap "Add Patient"
   - [ ] Enter share code: 123456
   - [ ] Tap "Add Patient"
   - [ ] Verify success message
   - [ ] Patient appears in list

3. **Verify CloudKit Records**
   - [ ] ShareInvitation: isActive = 0, dentistID = <dentist's Apple ID>
   - [ ] SharedPatientData: New record created with patientID and dentistID

4. **Test Data Access**
   - [ ] Tap on patient in dentist app
   - [ ] Verify patient detail view loads
   - [ ] If patient has data, verify it displays
   - [ ] Test time range selector (7/30/90 days)

5. **Test Revocation**
   - [ ] In patient app, go to Share → Shared Dentists
   - [ ] Tap "Revoke Access"
   - [ ] Confirm revocation
   - [ ] Verify SharedPatientData record: isActive = 0
   - [ ] In dentist app, refresh patient list
   - [ ] Patient should be removed

### Test Subscription Limits

**Patient App - Basic Tier**:
1. [ ] Share with 1st dentist - succeeds
2. [ ] Attempt 2nd share - upgrade prompt
3. [ ] Upgrade to Premium
4. [ ] Share with 2nd dentist - succeeds

**Dentist App - Starter Tier**:
1. [ ] Add 5 patients - all succeed
2. [ ] Attempt 6th patient - upgrade prompt
3. [ ] Upgrade to Professional
4. [ ] Add patients 6-50 - succeed
5. [ ] Upgrade to Practice
6. [ ] Add unlimited patients

---

## TestFlight Beta Testing

### Step 1: Archive Patient App

1. Select **OralableApp** scheme
2. Select **Any iOS Device** as destination
3. Product → Archive
4. Wait for archive to complete
5. In Organizer:
   - Select archive
   - Click **Distribute App**
   - Choose **TestFlight & App Store**
   - Follow prompts

### Step 2: Archive Dentist App

Repeat for **OralableForDentists** scheme

### Step 3: Add External Testers

1. In App Store Connect
2. Navigate to each app → TestFlight
3. Add external testers:
   - Real dentists for dentist app
   - Patients for patient app
4. Provide testing instructions

### Step 4: Beta Testing Checklist

**Patient App**:
- [ ] Onboarding flow smooth
- [ ] Device connection works (requires real Oralable device)
- [ ] Data recording functional
- [ ] Share code generation works
- [ ] Subscription purchase flow
- [ ] Data export works

**Dentist App**:
- [ ] Onboarding clear for dentists
- [ ] Share code entry intuitive
- [ ] Patient data displays correctly
- [ ] Analytics are meaningful
- [ ] Subscription upgrade flow
- [ ] Patient management efficient

**Cross-App Testing**:
- [ ] Share codes work between apps
- [ ] Data syncs within reasonable time
- [ ] Revocation works immediately
- [ ] Multiple dentists can access same patient (Premium)
- [ ] Subscription limits enforced

---

## Production Deployment

### Pre-Launch Checklist

**Technical**:
- [ ] All CloudKit record types deployed to production
- [ ] Subscription products approved in App Store Connect
- [ ] App Store listings complete (screenshots, descriptions)
- [ ] Privacy policy published at oralable.com
- [ ] Terms of service published
- [ ] Support email/website configured

**Legal/Compliance**:
- [ ] HIPAA compliance reviewed (if applicable in region)
- [ ] GDPR compliance ensured (EU)
- [ ] Data retention policies defined
- [ ] User consent flows implemented
- [ ] Age restrictions set (17+ medical)

**Testing**:
- [ ] Beta testing completed (min 2 weeks)
- [ ] Critical bugs fixed
- [ ] Performance tested (large datasets)
- [ ] Edge cases covered
- [ ] Accessibility tested

### Step 1: Submit for Review

**Patient App**:
1. App Store Connect → Oralable
2. Add version (1.0.0)
3. Upload screenshots (5.5", 6.5", 12.9" iPad)
4. Write description emphasizing:
   - Bruxism monitoring
   - Medical device integration
   - Dentist collaboration
5. Set pricing: Free with in-app purchase
6. Submit for review

**Dentist App**:
1. App Store Connect → Oralable for Dentists
2. Add version (1.0.0)
3. Upload professional screenshots
4. Description for healthcare providers:
   - Patient data management
   - Professional analytics
   - HIPAA/GDPR notes
5. Set pricing: Free with in-app purchase
6. Submit for review

### Step 2: App Review Process

**Common Rejection Reasons**:
- Missing privacy policy
- Unclear subscription terms
- Medical claims without evidence
- Missing app functionality in review build

**Response Time**:
- Initial review: 24-48 hours
- Rejections: Fix and resubmit within 24h
- Approval: Instant release or scheduled

### Step 3: Post-Launch Monitoring

**Week 1**:
- [ ] Monitor crash reports (Xcode Organizer)
- [ ] Check CloudKit quota usage
- [ ] Review user feedback
- [ ] Monitor subscription conversion rates
- [ ] Check for API errors

**Week 2-4**:
- [ ] Analyze user retention
- [ ] Identify common support issues
- [ ] Plan version 1.1 improvements
- [ ] Optimize subscription pricing if needed

---

## Monitoring & Analytics

### CloudKit Monitoring

1. **CloudKit Dashboard** → **Usage**
   - Monitor request rates
   - Check storage usage
   - Watch for errors

2. **Set Alerts**:
   - High error rates
   - Approaching quota limits
   - Unusual traffic patterns

### Subscription Analytics

**App Store Connect**:
- **Subscriptions** → **Dashboard**
- Monitor:
  - Conversion rates
  - Churn rates
  - Average revenue per user (ARPU)
  - Trial conversion

### Crash Reporting

**Xcode Organizer**:
1. Window → Organizer
2. **Crashes** tab
3. Review top crashes
4. Symbolicate and fix

### User Feedback

**App Store Connect**:
- Monitor ratings & reviews
- Respond to user feedback
- Identify feature requests
- Track sentiment

---

## Troubleshooting Production Issues

### Issue: Share Codes Not Working

**Symptoms**: Dentist enters code, gets "not found"

**Debug**:
1. Check CloudKit Dashboard → Data → ShareInvitation
2. Verify record exists with shareCode
3. Check isActive = 1
4. Check expiryDate not passed
5. Verify public permissions

**Fix**:
- Extend expiry if expired
- Check network connectivity
- Verify CloudKit container ID matches

### Issue: Subscription Not Restoring

**Symptoms**: User purchased but shows free tier

**Debug**:
1. Check StoreKit receipt
2. Verify product IDs match
3. Check App Store Connect product status
4. Review transaction logs

**Fix**:
- Call `AppStore.sync()`
- Restore purchases
- Check sandbox vs production

### Issue: Data Not Syncing

**Symptoms**: Patient data not visible to dentist

**Debug**:
1. Check HealthDataRecord in CloudKit
2. Verify patientID matches
3. Check dentist has active SharedPatientData
4. Review query predicates

**Fix**:
- Verify CloudKit indexes
- Check record permissions
- Force data refresh

---

## Success Metrics

### Key Performance Indicators (KPIs)

**User Acquisition**:
- Patient app downloads
- Dentist app downloads
- Conversion rate (download → signup)

**Engagement**:
- Daily active users (DAU)
- Monthly active users (MAU)
- Share code generation rate
- Average shares per patient

**Revenue**:
- Subscription conversion rate
- Monthly recurring revenue (MRR)
- Customer lifetime value (CLV)
- Churn rate

**Technical**:
- Crash-free rate (target: >99.5%)
- CloudKit success rate (target: >99%)
- Average API response time
- App launch time

---

## Next Version Planning

### Version 1.1 Ideas

**Patient App**:
- Export data to PDF
- Set bruxism alerts/goals
- Share with multiple dentists (Premium)
- Integration with Apple Health

**Dentist App**:
- Custom reports
- Bulk patient management
- Practice-wide analytics (Practice tier)
- Export patient cohort data

**Infrastructure**:
- Push notifications for new data
- Offline mode improvements
- Background data sync
- Widget support

---

## Support & Maintenance

### User Support Channels

- **Email**: support@oralable.com
- **Website**: oralable.com/support
- **In-App**: Help button → contact form

### Regular Maintenance

**Weekly**:
- Review crash reports
- Monitor CloudKit usage
- Check user feedback

**Monthly**:
- Analyze metrics
- Plan feature updates
- Security audit
- Dependency updates

**Quarterly**:
- Major version release
- Marketing campaigns
- Pricing optimization
- Competition analysis

---

## Conclusion

This testing and deployment guide provides a comprehensive path from local development to production. Follow each section carefully, and don't skip the testing phases - data integrity and user trust are critical for a medical app.

**Remember**:
- Test thoroughly before each release
- Monitor production closely after launch
- Respond quickly to user feedback
- Keep CloudKit schema stable
- Maintain HIPAA/GDPR compliance
- Document all changes

Good luck with your launch! 🚀
