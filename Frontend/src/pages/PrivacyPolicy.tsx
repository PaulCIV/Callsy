import { LegalPage, Section } from "./LegalPage";

export default function PrivacyPolicy() {
  return (
    <LegalPage title="Privacy Policy" updated="July 18, 2026">
      <Section title="Overview">
        <p>
          Callsy provides missed-call recovery and customer communication tools for businesses. This policy explains how Callsy processes information when a business uses Callsy or when a customer communicates with a business through a Callsy-powered phone number.
        </p>
      </Section>

      <Section title="Information we process">
        <p>We may process business account information, telephone numbers, call metadata, consent records, text-message content, appointment requests, support communications, and technical information needed to operate and secure the service.</p>
        <p>Callsy records the date, time, method, call identifier, and disclosure version associated with SMS consent when a caller elects to receive a text.</p>
      </Section>

      <Section title="How information is used">
        <p>Information is used to provide missed-call notifications, send requested customer-care messages, display conversations to the applicable business, support owner follow-up, detect urgent requests, improve reliability, prevent abuse, and comply with legal obligations.</p>
      </Section>

      <Section title="Mobile information and messaging consent">
        <p className="rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 font-medium text-emerald-950">
          Mobile information will not be shared with third parties or affiliates for marketing or promotional purposes. Text-messaging originator opt-in data and consent will not be sold, rented, or shared with third parties for their own marketing or promotional purposes.
        </p>
        <p>Callsy may disclose information to service providers, such as communications and hosting providers, only as necessary to deliver and secure the requested service. Those providers may not use mobile opt-in data for their own marketing.</p>
      </Section>

      <Section title="SMS choices">
        <p>Service-related message frequency varies according to customer interaction. Message and data rates may apply. Reply STOP to opt out of messages from the sending business. Reply HELP for assistance. Opting out of text messages does not prevent the customer from calling the business directly.</p>
      </Section>

      <Section title="Retention and security">
        <p>We retain information only for as long as reasonably necessary to operate the service, document consent, resolve disputes, enforce agreements, and meet legal requirements. We use reasonable administrative and technical safeguards, but no transmission or storage system can be guaranteed completely secure.</p>
      </Section>

      <Section title="Your choices and requests">
        <p>Customers may request access, correction, or deletion by contacting the business with which they communicated. Callsy business account holders may submit privacy requests through their account or their established Callsy support channel. Some records may be retained when legally required.</p>
      </Section>

      <Section title="Changes">
        <p>We may update this policy as the service changes. The updated date above identifies the latest version.</p>
      </Section>
    </LegalPage>
  );
}
